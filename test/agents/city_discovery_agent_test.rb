# frozen_string_literal: true

require "test_helper"

class CityDiscoveryAgentTest < ActiveSupport::TestCase
  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end

    Llm::ModelRegistry.ensure_configured_model!(model_id: @model_id)
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "create! includes country context, continent name, existing city names, and Marseille JSON example" do
    chat = CityDiscoveryAgent.create!(
      country_name: "France",
      country_description: "Western European sovereign republic.",
      country_themes: [ "republic", "nuclear power", "diplomacy" ],
      continent_name: "Europe",
      existing_names: [ "Paris", "Lyon" ]
    )

    assert chat.persisted?
    assert_nil chat.schema

    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "France"
    assert_includes system_message.content, "Europe"
    assert_includes system_message.content, "Western European sovereign republic."
    assert_includes system_message.content, "republic, nuclear power, diplomacy"
    assert_includes system_message.content, "Paris, Lyon"
    assert_includes system_message.content, "Marseille"
    assert_includes system_message.content, '"cities"'
    assert_includes system_message.content, '"themes"'
  end
end
