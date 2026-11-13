# frozen_string_literal: true

require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @continent = Continent.create!(name: "Asia", description: "Asian continent.")
    @vector = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }

    @country = Country.create!(
      continent: @continent,
      name: "Japan",
      description: "East Asian island state with high technology and industrial power.",
      themes: [ "island", "tech", "export" ],
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    @city = City.create!(
      country: @country,
      name: "Tokyo",
      description: "Megacity capital and global financial center.",
      themes: [ "capital", "finance", "megacity" ],
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/search requires q parameter" do
    get api_v1_search_url, as: :json
    assert_response :bad_request
    assert_equal "blank_query", response.parsed_body.dig("error", "code")
  end

  test "GET /api/v1/search returns results for keyword search" do
    get api_v1_search_url, params: { q: "megacity", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "keyword", json.dig("meta", "mode")
  end

  test "GET /api/v1/countries/search performs keyword search" do
    get search_api_v1_countries_url, params: { q: "Japan", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Japan", json["data"].first["name"]
  end

  test "GET /api/v1/cities/search performs keyword search" do
    get search_api_v1_cities_url, params: { q: "financial", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal @city.id, json["data"].first["id"]
  end
end
