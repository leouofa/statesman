# frozen_string_literal: true

class PopulateContinentsJob < ApplicationJob
  STREAM_NAME = "continents"
  DISCOVERY_PROMPT = "Identify all 7 world continents (Africa, Antarctica, Asia, Europe, North America, Oceania, South America) and return their canonical names and geopolitical, strategic geography, and political-economy descriptions as JSON."

  queue_as :default
  sidekiq_options retry: 0

  def perform
    Llm::ModelRegistry.ensure_configured_model!

    existing_names = Continent.ordered.pluck(:name)
    chat = ContinentDiscoveryAgent.create!(existing_names: existing_names)
    response = chat.ask(DISCOVERY_PROMPT)

    entries = extract_continents(response)
    upserted = Continent.upsert_batch!(entries)
    raise "LLM response did not contain any valid continents." if upserted.empty?

    message = "Upserted #{upserted.size} #{'continent'.pluralize(upserted.size)} (#{Continent.count} total)."
    track_completed(message: message, result: { upserted_count: upserted.size, total_count: Continent.count })

    broadcast_state(
      status_message: message,
      status_kind: :success,
      running: false
    )
    { upserted_count: upserted.size, total_count: Continent.count }
  rescue StandardError => e
    Rails.logger.error("[PopulateContinentsJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate continents: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate continents: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def extract_continents(response)
    Llm::JsonResponseParser.extract_list(response, key: "continents")
  end

  def broadcast_state(status_message:, status_kind:, running:)
    continents = Continent.ordered.to_a

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_controls",
        action_path: Rails.application.routes.url_helpers.populate_continents_path,
        idle_label: "Populate Continents",
        running_label: "Discovering Continents...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "continents_list",
      partial: "pages/continents_list",
      locals: { continents: continents }
    )
  end
end
