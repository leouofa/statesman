# frozen_string_literal: true

require "test_helper"

class Api::V1::CitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @continent = Continent.create!(name: "Europe", description: "European continent.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.98 : 0.02 }

    @country = Country.create!(continent: @continent, name: "France", description: "French Republic.", themes: [ "republic" ])
    @other_country = Country.create!(continent: @continent, name: "Germany", description: "Federal Republic.", themes: [ "federal" ])

    @city = City.create!(
      country: @country,
      name: "Paris",
      description: "National capital and economic hub.",
      themes: [ "capital", "diplomacy" ],
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/cities returns list" do
    get api_v1_cities_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal 1, json["data"].size
    assert_equal "Paris", json["data"].first["name"]
    assert_equal "France", json["data"].first.dig("country", "name")
  end

  test "GET /api/v1/cities/:id returns city" do
    get api_v1_city_url(@city), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @city.id, json.dig("data", "id")
    assert_equal "Paris", json.dig("data", "name")
    assert_includes json.dig("data", "themes"), "capital"
  end

  test "POST /api/v1/cities creates city for a country" do
    assert_difference("City.count", 1) do
      post api_v1_cities_url, params: {
        city: {
          country_id: @other_country.id,
          name: "Berlin",
          description: "Federal capital and cultural center.",
          themes: [ "capital", "culture" ]
        }
      }, as: :json
    end
    assert_response :created
    assert_equal "Berlin", response.parsed_body.dig("data", "name")
    assert_equal @other_country.id, response.parsed_body.dig("data", "country_id")
  end

  test "PATCH /api/v1/cities/:id updates city" do
    patch api_v1_city_url(@city), params: {
      city: {
        description: "Updated Paris description."
      }
    }, as: :json
    assert_response :success
    assert_equal "Updated Paris description.", @city.reload.description
  end

  test "DELETE /api/v1/cities/:id deletes city" do
    assert_difference("City.count", -1) do
      delete api_v1_city_url(@city), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/cities/:id/neighbors finds nearest cities" do
    other_city = City.create!(
      country: @country,
      name: "Lyon",
      description: "Gastronomic and industrial hub.",
      themes: [ "industry", "culinary" ],
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_city_url(@city), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal other_city.id, json["data"].first["id"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/cities/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_city_url(@city), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end
