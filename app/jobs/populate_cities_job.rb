# frozen_string_literal: true

class PopulateCitiesJob < ApplicationJob
  STREAM_NAME = "cities"

  queue_as :default
  sidekiq_options retry: 0

  def perform(country_id: nil)
    Llm::ModelRegistry.ensure_configured_model!

    countries = if country_id.present?
                  Country.where(id: country_id).includes(:continent).to_a
    else
                  Country.includes(:continent).joins(:continent).order("continents.name ASC, countries.name ASC").to_a
    end

    if countries.empty?
      msg = country_id.present? ? "Country with ID #{country_id} not found." : "No countries found. Populate countries first before discovering cities."
      track_failed(error: msg, message: msg)
      broadcast_state(
        status_message: msg,
        status_kind: :error,
        running: false
      )
      return { total_upserted: 0, failed_countries: [] }
    end

    total_upserted, failed_countries = populate_across_countries(countries)
    summary = build_summary(total_upserted: total_upserted, total_countries: countries.size, failed_countries: failed_countries)

    if failed_countries.size == countries.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(
        message: summary[:message],
        result: { total_upserted: total_upserted, total_cities: City.count, failed_countries: failed_countries }
      )
    end

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )

    { total_upserted: total_upserted, failed_countries: failed_countries }
  rescue StandardError => e
    Rails.logger.error("[PopulateCitiesJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate cities: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate cities: #{e.message}",
      status_kind: :error,
      running: false
    )
  end

  def populate_country!(country)
    existing_names = country.cities.ordered.pluck(:name)
    chat = CityDiscoveryAgent.create!(
      country_name: country.name,
      country_description: country.description,
      country_themes: country.themes,
      continent_name: country.continent.name,
      existing_names: existing_names
    )
    response = chat.ask(discovery_prompt_for(country))

    entries = Llm::JsonResponseParser.extract_list(response, key: "cities")
    upserted = City.upsert_batch!(country, entries)
    raise "LLM response did not contain any valid cities for #{country.name}." if upserted.empty?

    upserted.size
  end

  private

  def populate_across_countries(countries)
    total_upserted = 0
    failed_countries = []

    countries.each_with_index do |country, index|
      msg = "Discovering cities for #{country.name} (#{index + 1}/#{countries.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: countries.size, country: country.name })
      broadcast_state(
        status_message: msg,
        status_kind: :info,
        running: true
      )

      total_upserted += populate_country!(country)
    rescue StandardError => e
      Rails.logger.error("[PopulateCitiesJob] Country=#{country.name} #{e.class}: #{e.message}")
      failed_countries << country.name
    end

    [ total_upserted, failed_countries ]
  end

  def discovery_prompt_for(country)
    "Identify 8 to 10 major, economically central, or strategically vital cities in #{country.name} (#{country.continent.name}) and return them as a JSON list with name, description, and thematic tags."
  end

  def build_summary(total_upserted:, total_countries:, failed_countries:)
    total_cities = City.count
    if failed_countries.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'city'.pluralize(total_upserted)} across #{total_countries} #{'country'.pluralize(total_countries)} (#{total_cities} total)."
      }
    elsif failed_countries.size == total_countries
      {
        kind: :error,
        message: "Failed to populate cities for all countries: #{failed_countries.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'city'.pluralize(total_upserted)} (#{total_cities} total). Failed countries: #{failed_countries.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    country_groups = City.grouped_by_country
    total_cities_count = City.count
    countries_count = Country.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "cities_populate_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "cities_populate_controls",
        action_path: Rails.application.routes.url_helpers.populate_cities_path,
        idle_label: "Populate Cities",
        running_label: "Discovering Cities...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "cities_list",
      partial: "pages/cities_list",
      locals: {
        country_groups: country_groups,
        total_cities_count: total_cities_count,
        countries_count: countries_count
      }
    )
  end
end
