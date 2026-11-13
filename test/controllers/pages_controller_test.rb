# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home renders empty state and populate button when no continents exist" do
    get root_url

    assert_response :success
    assert_select "h1", "Continents"
    assert_select "button", /Populate Continents/
    assert_match "No continents yet", response.body
  end

  test "home lists all continents ordered by name" do
    Continent.create!(name: "Europe", description: "European continent.")
    Continent.create!(name: "Asia", description: "Asian continent.")

    get root_url

    assert_response :success
    assert_select "article h2", count: 2
    assert_operator response.body.index("Asia"), :<, response.body.index("Europe")
    assert_match "European continent.", response.body
    assert_match "Asian continent.", response.body
  end

  test "countries renders empty state and populate button when no countries exist" do
    get countries_url

    assert_response :success
    assert_select "h1", "Countries"
    assert_select "button", /Populate Countries/
    assert_match "No countries yet", response.body
  end

  test "countries lists all countries in a table grouped by continent headers with themes" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    asia = Continent.create!(name: "Asia", description: "Asian continent.")

    Country.create!(continent: asia, name: "Japan", description: "East Asian state.", themes: [ "island", "tech" ])
    Country.create!(continent: europe, name: "France", description: "Western European republic.", themes: [ "republic", "nuclear" ])
    Country.create!(continent: europe, name: "Germany", description: "Central European republic.", themes: [ "federal", "manufacturing" ])

    get countries_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Asia/
    assert_select "table tbody tr th", /Europe/
    assert_operator response.body.index("Asia"), :<, response.body.index("Europe")
    assert_operator response.body.index("France"), :<, response.body.index("Germany")
    assert_match "East Asian state.", response.body
    assert_match "nuclear", response.body
    assert_match "republic", response.body
    assert_match "tech", response.body
  end

  test "cities renders empty state, populate button, and top navbar link when no cities exist" do
    get cities_url

    assert_response :success
    assert_select "nav a[href=?]", cities_path, text: "Cities"
    assert_select "h1", "Cities"
    assert_select "button", /Populate Cities/
    assert_match "No cities yet", response.body
  end

  test "cities lists all cities in a table grouped by country headers" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    asia = Continent.create!(name: "Asia", description: "Asian continent.")

    france = Country.create!(continent: europe, name: "France", description: "Western Europe.")
    japan = Country.create!(continent: asia, name: "Japan", description: "East Asia.")

    City.create!(country: france, name: "Paris", description: "French capital.", themes: [ "capital", "diplomacy" ])
    City.create!(country: france, name: "Marseille", description: "Mediterranean port gateway.", themes: [ "port" ])
    City.create!(country: japan, name: "Tokyo", description: "Megacity capital.", themes: [ "capital", "finance" ])

    get cities_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Japan/
    assert_select "table tbody tr th", /France/
    assert_match "Paris", response.body
    assert_match "Marseille", response.body
    assert_match "Tokyo", response.body
    assert_match "Mediterranean port gateway.", response.body
  end
end
