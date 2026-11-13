# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateCountriesJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "perform iterates through continents, upserts countries with themes, and streams progress" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    asia = Continent.create!(name: "Asia", description: "Asian continent.")
    Country.create!(continent: europe, name: "France", description: "Initial France description", themes: [ "republic" ])

    calls = []
    responses = {
      "Europe" => <<~TEXT,
        <think>Listing European countries.</think>
        ```json
        {
          "countries": [
            { "name": "France", "description": "Fifth Republic.", "themes": ["republic", "nuclear power"] },
            { "name": "Germany", "description": "Federal Republic.", "themes": ["federal", "industrial"] }
          ]
        }
        ```
      TEXT
      "Asia" => {
        "countries" => [
          { "name": "Japan", "description": "Island state in East Asia.", "themes": [ "island", "tech" ] }
        ]
      }.to_json
    }

    with_stubbed_agent_create(->(continent_name:, continent_description:, existing_names:) {
      calls << { continent_name: continent_name, continent_description: continent_description, existing_names: existing_names }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(continent_name))
      end
      fake_chat
    }) do
      # 2 continents * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateCountriesJob::STREAM_NAME, 6) do
        PopulateCountriesJob.perform_now
      end
    end

    assert_equal [ "Asia", "Europe" ], calls.map { |c| c[:continent_name] } # Continent.ordered sorts alphabetically: Asia, Europe
    assert_equal [], calls.first[:existing_names] # Asia has none initially
    assert_equal [ "France" ], calls.second[:existing_names] # Europe has France

    assert_equal 3, Country.count
    france = europe.countries.find_by!(name: "France")
    assert_equal "Fifth Republic.", france.description
    assert_equal [ "republic", "nuclear power" ], france.themes

    japan = asia.countries.find_by!(name: "Japan")
    assert_equal [ "island", "tech" ], japan.themes
  end

  test "perform skips Antarctica cleanly without failing" do
    antarctica = Continent.create!(name: "Antarctica", description: "Southernmost continent.")
    europe = Continent.create!(name: "Europe", description: "European continent.")

    calls = []
    with_stubbed_agent_create(->(continent_name:, **) {
      calls << continent_name
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(
          parsed: nil,
          content: {
            "countries" => [
              { "name": "France", "description": "Western Europe.", "themes": [ "republic" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      PopulateCountriesJob.perform_now
    end

    assert_equal [ "Europe" ], calls
    assert_equal 0, antarctica.countries.count
    assert_equal 1, europe.countries.count
  end

  test "perform continues to remaining continents if one continent fails" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    asia = Continent.create!(name: "Asia", description: "Asian continent.")

    with_stubbed_agent_create(->(continent_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on Asia" if continent_name == "Asia"

        OpenStruct.new(
          parsed: nil,
          content: {
            "countries" => [
              { "name" => "France", "description" => "Western Europe.", "themes" => [ "republic" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateCountriesJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateCountriesJob.perform_now }
      end
    end

    assert_equal 1, Country.count
    assert_equal "France", Country.first.name
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = CountryDiscoveryAgent.singleton_class
    original = CountryDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
