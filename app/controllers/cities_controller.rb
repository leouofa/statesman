# frozen_string_literal: true

class CitiesController < ApplicationController
  include EmbeddableActions

  def show
    @city = City.includes(country: :continent).find(params[:id])
  end

  def generate_embedding
    @city = City.find(params[:id])
    enqueue_embedding_generation(@city)
  end

  def populate
    PopulateCitiesJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "cities_populate_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "cities_populate_controls",
            action_path: populate_cities_path,
            idle_label: "Populate Cities",
            running_label: "Discovering Cities...",
            running: true,
            status_message: "Asking the agent to discover cities across countries...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to cities_path, notice: "Asking the agent to discover cities across countries..." }
    end
  end
end
