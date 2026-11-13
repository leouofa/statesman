# frozen_string_literal: true

require "test_helper"

class Api::V1::ContinentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @continent = Continent.create!(name: "Europe", description: "European continent.")
  end

  test "GET /api/v1/continents returns list" do
    get api_v1_continents_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert json["meta"].key?("total")
    names = json["data"].map { |p| p["name"] }
    assert_includes names, "Europe"
  end

  test "GET /api/v1/continents/:id returns single continent" do
    get api_v1_continent_url(@continent), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @continent.name, json.dig("data", "name")
  end

  test "POST /api/v1/continents creates a new continent" do
    assert_difference("Continent.count", 1) do
      post api_v1_continents_url, params: { continent: { name: "Asia", description: "Asian continent." } }, as: :json
    end
    assert_response :created

    json = response.parsed_body
    assert_equal "Asia", json.dig("data", "name")
  end

  test "PATCH /api/v1/continents/:id updates a continent" do
    patch api_v1_continent_url(@continent), params: { continent: { description: "Updated description" } }, as: :json
    assert_response :success

    @continent.reload
    assert_equal "Updated description", @continent.description
  end

  test "DELETE /api/v1/continents/:id removes a continent" do
    assert_difference("Continent.count", -1) do
      delete api_v1_continent_url(@continent), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "POST /api/v1/continents/upsert_batch upserts multiple continents" do
    payload = {
      continents: [
        { name: "Europe", description: "New Europe description" },
        { name: "Africa", description: "African continent." }
      ]
    }

    assert_difference("Continent.count", 1) do
      post upsert_batch_api_v1_continents_url, params: payload, as: :json
    end
    assert_response :success

    assert_equal "New Europe description", @continent.reload.description
    assert Continent.find_by(name: "Africa")
  end

  test "POST /api/v1/continents/populate enqueues PopulateContinentsJob by default" do
    assert_enqueued_with(job: PopulateContinentsJob) do
      post populate_api_v1_continents_url, as: :json
    end
    assert_response :accepted
    assert response.parsed_body.dig("data", "job_id").present?
  end

  test "POST /api/v1/continents/:id/populate_countries enqueues PopulateCountriesJob" do
    assert_enqueued_with(job: PopulateCountriesJob, args: [ { continent_id: @continent.id } ]) do
      post populate_countries_api_v1_continent_url(@continent), as: :json
    end
    assert_response :accepted
  end
end
