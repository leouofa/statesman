# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateCitiesJobTest < ActiveSupport::TestCase
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

  test "perform iterates through countries, upserts cities with themes, and streams progress" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    france = Country.create!(continent: europe, name: "France", description: "Western Europe.", themes: [ "republic" ])
    germany = Country.create!(continent: europe, name: "Germany", description: "Central Europe.", themes: [ "federal" ])
    City.create!(country: france, name: "Paris", description: "Initial Paris description", themes: [ "capital" ])

    calls = []
    responses = {
      "France" => <<~TEXT,
        <think>Listing French cities.</think>
        ```json
        {
          "cities": [
            { "name": "Paris", "description": "National capital and economic hub.", "themes": ["capital", "diplomacy"] },
            { "name": "Marseille", "description": "Mediterranean port gateway.", "themes": ["port", "logistics"] }
          ]
        }
        ```
      TEXT
      "Germany" => {
        "cities" => [
          { "name": "Berlin", "description": "Federal capital and cultural center.", "themes": [ "capital", "culture" ] }
        ]
      }.to_json
    }

    with_stubbed_agent_create(->(country_name:, country_description:, country_themes:, continent_name:, existing_names:) {
      calls << {
        country_name: country_name,
        country_description: country_description,
        country_themes: country_themes,
        continent_name: continent_name,
        existing_names: existing_names
      }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(country_name))
      end
      fake_chat
    }) do
      # 2 countries * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateCitiesJob::STREAM_NAME, 6) do
        PopulateCitiesJob.perform_now
      end
    end

    assert_equal [ "France", "Germany" ], calls.map { |c| c[:country_name] }
    assert_equal [ "Paris" ], calls.first[:existing_names]
    assert_equal [], calls.second[:existing_names]

    assert_equal 3, City.count
    paris = france.cities.find_by!(name: "Paris")
    assert_equal "National capital and economic hub.", paris.description
    assert_equal [ "capital", "diplomacy" ], paris.themes

    berlin = germany.cities.find_by!(name: "Berlin")
    assert_equal [ "capital", "culture" ], berlin.themes
  end

  test "perform continues to remaining countries if one country fails" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    france = Country.create!(continent: europe, name: "France", description: "Western Europe.")
    germany = Country.create!(continent: europe, name: "Germany", description: "Central Europe.")

    with_stubbed_agent_create(->(country_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on France" if country_name == "France"

        OpenStruct.new(
          parsed: nil,
          content: {
            "cities" => [
              { "name": "Berlin", "description": "Federal capital.", "themes": [ "capital" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateCitiesJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateCitiesJob.perform_now }
      end
    end

    assert_equal 1, City.count
    assert_equal "Berlin", City.first.name
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = CityDiscoveryAgent.singleton_class
    original = CityDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
