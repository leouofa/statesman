# frozen_string_literal: true

module Api
  module V1
    class StatusController < BaseController
      def show
        render_success(
          {
            status: "ok",
            environment: Rails.env,
            timestamp: Time.current.iso8601,
            counts: {
              continents: Continent.count,
              countries: Country.count,
              countries_embedded: Country.where.not(embedding: nil).count,
              cities: City.count,
              cities_embedded: City.where.not(embedding: nil).count,
              cluster_snapshots: ClusterSnapshot.count,
              cluster_reports: ClusterReport.count
            },
            config: {
              embedding_model: Llm::EmbeddingGenerator.configured_model,
              embedding_api_base: Llm::EmbeddingGenerator.configured_api_base,
              embedding_dimensions: Llm::EmbeddingGenerator::DIMENSIONS,
              llm_model: ENV["OLLAMA_MODEL"],
              llm_api_base: ENV["OLLAMA_API_BASE"],
              context_window: Llm::ModelRegistry.current_context_window,
              digest_char_budget: Llm::ModelRegistry.digest_char_budget
            }
          }
        )
      end
    end
  end
end
