# frozen_string_literal: true

require "test_helper"

class Api::V1::CountriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @continent = Continent.create!(name: "Europe", description: "European continent.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.99 : 0.01 }

    @country = Country.create!(
      continent: @continent,
      name: "France",
      description: "Western European republic.",
      themes: [ "republic", "nuclear", "diplomacy" ],
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/countries returns list with filtering" do
    get api_v1_countries_url, params: { continent_id: @continent.id, theme: "nuclear" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "France", json["data"].first["name"]
    assert_equal false, json["data"].first.key?("embedding")
  end

  test "GET /api/v1/countries/:id returns country with continent details" do
    get api_v1_country_url(@country), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "France", json.dig("data", "name")
    assert_equal "Europe", json.dig("data", "continent", "name")
  end

  test "GET /api/v1/countries/:id with include_embedding=true returns raw vector" do
    get api_v1_country_url(@country), params: { include_embedding: "true" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json.dig("data", "embedding").is_a?(Array)
    assert_equal 1024, json.dig("data", "embedding").size
  end

  test "POST /api/v1/countries creates a country" do
    assert_difference("Country.count", 1) do
      post api_v1_countries_url, params: {
        country: {
          continent_id: @continent.id,
          name: "Germany",
          description: "Central European federal state.",
          themes: [ "federal", "manufacturing" ]
        }
      }, as: :json
    end
    assert_response :created
    assert_equal "Germany", response.parsed_body.dig("data", "name")
  end

  test "PATCH /api/v1/countries/:id updates country" do
    patch api_v1_country_url(@country), params: { country: { description: "Updated France description" } }, as: :json
    assert_response :success
    assert_equal "Updated France description", @country.reload.description
  end

  test "DELETE /api/v1/countries/:id deletes country" do
    assert_difference("Country.count", -1) do
      delete api_v1_country_url(@country), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/countries/:id/neighbors finds nearest countries" do
    other = Country.create!(
      continent: @continent,
      name: "United Kingdom",
      description: "Island monarchy.",
      themes: [ "monarchy", "maritime" ],
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_country_url(@country), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "United Kingdom", json["data"].first["name"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/countries/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_country_url(@country), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end
