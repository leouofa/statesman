# frozen_string_literal: true

require "test_helper"

class CitiesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateCitiesJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateCitiesJob) do
      post populate_cities_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Cities...", response.body
  end

  test "populate enqueues PopulateCitiesJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateCitiesJob) do
      post populate_cities_url
    end

    assert_redirected_to cities_url
  end

  test "show renders city details and Generate Embedding button" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "Western European republic.")
    city = City.create!(country: country, name: "Paris", description: "National capital.", themes: [ "capital" ])

    get city_url(city)

    assert_response :success
    assert_match "Paris", response.body
    assert_match "France", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "Western European republic.")
    city = City.create!(country: country, name: "Paris", description: "National capital.", themes: [ "capital" ])

    get city_url(city), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "Paris", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full City Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "Western European republic.")
    city = City.create!(country: country, name: "Paris", description: "National capital.", themes: [ "capital" ])

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "City", city.id ]) do
      post generate_embedding_city_url(city), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "Western European republic.")
    city = City.create!(country: country, name: "Paris", description: "National capital.", themes: [ "capital" ])

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "City", city.id ]) do
      post generate_embedding_city_url(city)
    end

    assert_redirected_to city_url(city)
  end
end
