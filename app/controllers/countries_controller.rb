# frozen_string_literal: true

class CountriesController < ApplicationController
  include EmbeddableActions

  def show
    @country = Country.includes(:continent, :cities).find(params[:id])
  end

  def generate_embedding
    @country = Country.find(params[:id])
    enqueue_embedding_generation(@country)
  end

  def populate_cities
    @country = Country.find(params[:id])
    PopulateCitiesJob.perform_later(country_id: @country.id)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Discovering cities for #{@country.name}..."
        render turbo_stream: turbo_stream.replace(
          "country_cities_section",
          partial: "countries/cities_section",
          locals: { country: @country, status_message: flash.now[:notice], status_kind: :info }
        )
      end
      format.html { redirect_to country_path(@country), notice: "Discovering cities for #{@country.name}..." }
    end
  end

  def populate
    PopulateCountriesJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "countries_populate_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "countries_populate_controls",
            action_path: populate_countries_path,
            idle_label: "Populate Countries",
            running_label: "Discovering Countries...",
            running: true,
            status_message: "Asking the agent to discover sovereign states across continents...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to countries_path, notice: "Asking the agent to discover sovereign states across continents..." }
    end
  end
end
