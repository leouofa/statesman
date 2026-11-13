# frozen_string_literal: true

class PopulateCountriesJob < ApplicationJob
  STREAM_NAME = "countries"

  queue_as :default
  sidekiq_options retry: 0

  def perform(continent_id: nil)
    Llm::ModelRegistry.ensure_configured_model!

    continents = if continent_id.present?
                   Continent.where(id: continent_id).to_a
    else
                   Continent.ordered.to_a
    end

    if continents.empty?
      msg = continent_id.present? ? "Continent with ID #{continent_id} not found." : "No continents found. Populate continents first before discovering countries."
      track_failed(error: msg, message: msg)
      broadcast_state(
        status_message: msg,
        status_kind: :error,
        running: false
      )
      return { total_upserted: 0, failed_continents: [] }
    end

    total_upserted, failed_continents = populate_across_continents(continents)
    summary = build_summary(total_upserted: total_upserted, total_continents: continents.size, failed_continents: failed_continents)

    if failed_continents.size == continents.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(
        message: summary[:message],
        result: { total_upserted: total_upserted, total_countries: Country.count, failed_continents: failed_continents }
      )
    end

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )

    { total_upserted: total_upserted, failed_continents: failed_continents }
  rescue StandardError => e
    Rails.logger.error("[PopulateCountriesJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate countries: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate countries: #{e.message}",
      status_kind: :error,
      running: false
    )
  end

  def populate_continent!(continent)
    return 0 if continent.antarctica?

    existing_names = continent.countries.ordered.pluck(:name)
    chat = CountryDiscoveryAgent.create!(
      continent_name: continent.name,
      continent_description: continent.description,
      existing_names: existing_names
    )
    response = chat.ask(discovery_prompt_for(continent))

    entries = Llm::JsonResponseParser.extract_list(response, key: "countries")
    upserted = Country.upsert_batch!(continent, entries)
    raise "LLM response did not contain any valid countries for #{continent.name}." if upserted.empty?

    upserted.size
  end

  private

  def populate_across_continents(continents)
    total_upserted = 0
    failed_continents = []

    continents.each_with_index do |continent, index|
      if continent.antarctica?
        msg = "Skipping #{continent.name} (no sovereign states)..."
        track_progress(message: msg, progress: { current: index + 1, total: continents.size, continent: continent.name })
        next
      end

      msg = "Discovering countries for #{continent.name} (#{index + 1}/#{continents.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: continents.size, continent: continent.name })
      broadcast_state(
        status_message: msg,
        status_kind: :info,
        running: true
      )

      total_upserted += populate_continent!(continent)
    rescue StandardError => e
      Rails.logger.error("[PopulateCountriesJob] Continent=#{continent.name} #{e.class}: #{e.message}")
      failed_continents << continent.name
    end

    [ total_upserted, failed_continents ]
  end

  def discovery_prompt_for(continent)
    "Find all sovereign states belonging to #{continent.name} and return their names, descriptions, and thematic tags as JSON."
  end

  def build_summary(total_upserted:, total_continents:, failed_continents:)
    total_countries = Country.count
    if failed_continents.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'country'.pluralize(total_upserted)} across #{total_continents} #{'continent'.pluralize(total_continents)} (#{total_countries} total)."
      }
    elsif failed_continents.size == total_continents
      {
        kind: :error,
        message: "Failed to populate countries for all continents: #{failed_continents.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'country'.pluralize(total_upserted)} (#{total_countries} total). Failed continents: #{failed_continents.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    continent_groups = Country.grouped_by_continent
    total_countries_count = Country.count
    continents_count = Continent.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "countries_populate_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "countries_populate_controls",
        action_path: Rails.application.routes.url_helpers.populate_countries_path,
        idle_label: "Populate Countries",
        running_label: "Discovering Countries...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "countries_list",
      partial: "pages/countries_list",
      locals: {
        continent_groups: continent_groups,
        total_countries_count: total_countries_count,
        continents_count: continents_count
      }
    )
  end
end
