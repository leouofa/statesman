# frozen_string_literal: true

require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"
    @previous_model = ENV["OLLAMA_MODEL"]
    ENV["OLLAMA_MODEL"] = @model_id
    Llm::ModelRegistry.ensure_configured_model!(model_id: @model_id)
  end

  teardown do
    if @previous_model.nil?
      ENV.delete("OLLAMA_MODEL")
    else
      ENV["OLLAMA_MODEL"] = @previous_model
    end
  end

  test "show renders settings page with nav link, config, coverage, and bulk buttons" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    france = Country.create!(
      continent: europe,
      name: "France",
      description: "French Republic.",
      embedding: Array.new(1024, 0.1),
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
    Country.create!(continent: europe, name: "Germany", description: "Federal Republic.")
    City.create!(country: france, name: "Paris", description: "Capital.", themes: [ "capital" ])

    get settings_url

    assert_response :success
    assert_match "Settings", response.body
    assert_match "1 / 2 embedded", response.body
    assert_match "0 / 1 embedded", response.body
    assert_match "Generate Missing", response.body
    assert_match "Regenerate All", response.body
    assert_match Llm::EmbeddingGenerator.configured_model, response.body
  end

  test "generate_embeddings enqueues GenerateAllEmbeddingsJob and responds with turbo stream" do
    assert_enqueued_with(job: GenerateAllEmbeddingsJob, args: [ "Country", { only_missing: true } ]) do
      post generate_embeddings_settings_url, params: { model_type: "Country", only_missing: true }, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Missing...", response.body
  end

  test "generate_embeddings enqueues Regenerate All and redirects for HTML requests" do
    assert_enqueued_with(job: GenerateAllEmbeddingsJob, args: [ "City", { only_missing: false } ]) do
      post generate_embeddings_settings_url, params: { model_type: "City", only_missing: false }
    end

    assert_redirected_to settings_url
  end

  test "generate_embeddings rejects unsupported model_type" do
    assert_no_enqueued_jobs(only: GenerateAllEmbeddingsJob) do
      post generate_embeddings_settings_url, params: { model_type: "Continent", only_missing: true }
    end

    assert_response :unprocessable_entity
  end

  test "update_context_window updates tokens and redirects with notice" do
    patch update_context_window_settings_url, params: { context_window: 131_072 }
    assert_redirected_to settings_url
    assert_equal "LLM Context Window updated to 131,072 tokens.", flash[:notice]
  end
end
