# frozen_string_literal: true

require "test_helper"

class CountriesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateCountriesJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateCountriesJob) do
      post populate_countries_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Countries...", response.body
  end

  test "populate enqueues PopulateCountriesJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateCountriesJob) do
      post populate_countries_url
    end

    assert_redirected_to countries_url
  end

  test "show renders country details and Generate Embedding button" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "Western European republic.", themes: [ "republic" ])

    get country_url(country)

    assert_response :success
    assert_match "France", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "Western European republic.", themes: [ "republic" ])

    get country_url(country), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "France", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full Country Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "Western European republic.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "Country", country.id ]) do
      post generate_embedding_country_url(country), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "Western European republic.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "Country", country.id ]) do
      post generate_embedding_country_url(country)
    end

    assert_redirected_to country_url(country)
  end
end
