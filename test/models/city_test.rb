# frozen_string_literal: true

require "test_helper"

class CityTest < ActiveSupport::TestCase
  test "validates presence of name, description, and country" do
    city = City.new(name: " ", description: " ")
    assert_not city.valid?
    assert_includes city.errors[:country], "must exist"
    assert_includes city.errors[:name], "can't be blank"
    assert_includes city.errors[:description], "can't be blank"
  end

  test "normalizes name, description, and themes" do
    continent = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: continent, name: "France", description: "French Republic.")
    city = City.create!(
      country: country,
      name: "  Paris   City ",
      description: "  Capital and financial center.  ",
      themes: [ " diplomacy ", "Finance", "DIPLOMACY", "", nil ]
    )

    assert_equal "Paris City", city.name
    assert_equal "Capital and financial center.", city.description
    assert_equal [ "diplomacy", "Finance" ], city.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    continent = Continent.create!(name: "Asia", description: "Asian continent.")
    country = Country.create!(continent: continent, name: "Japan", description: "East Asian state.")
    city = City.create!(
      country: country,
      name: "Tokyo",
      description: "Capital of Japan.",
      themes: "megacity, global finance, robotics, Megacity"
    )

    assert_equal [ "megacity", "global finance", "robotics" ], city.themes
  end

  test "enforces case-insensitive uniqueness scoped per country" do
    continent = Continent.create!(name: "Europe", description: "European continent.")
    france = Country.create!(continent: continent, name: "France", description: "French Republic.")
    usa_continent = Continent.create!(name: "North America", description: "North American continent.")
    usa = Country.create!(continent: usa_continent, name: "United States", description: "Federal Republic.")

    City.create!(country: france, name: "Paris", description: "French capital.")

    same_country_dup = City.new(country: france, name: "paris", description: "Duplicate.")
    assert_not same_country_dup.valid?
    assert_includes same_country_dup.errors[:name], "has already been taken"

    other_country_city = City.new(country: usa, name: "Paris", description: "Paris, Texas.")
    assert other_country_city.valid?
  end

  test "upsert_batch! inserts new cities and updates existing ones within a country" do
    continent = Continent.create!(name: "Europe", description: "European continent.")
    france = Country.create!(continent: continent, name: "France", description: "French Republic.")
    germany = Country.create!(continent: continent, name: "Germany", description: "Federal Republic.")

    City.create!(country: france, name: "Paris", description: "Old description", themes: [ "capital" ])
    City.create!(country: germany, name: "Paris", description: "Different Paris", themes: [ "town" ])

    results = City.upsert_batch!(france, [
      { "name" => "  paris ", "description" => "Global diplomatic hub.", "themes" => [ "capital", "diplomacy" ] },
      { "name" => "Marseille", "description" => "Port city.", "themes" => [ "maritime", "trade" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Lyon", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, france.cities.count
    assert_equal 1, germany.cities.count

    france_paris = france.cities.find_by!("LOWER(name) = ?", "paris")
    assert_equal "paris", france_paris.name
    assert_equal "Global diplomatic hub.", france_paris.description
    assert_equal [ "capital", "diplomacy" ], france_paris.themes

    marseille = france.cities.find_by!(name: "Marseille")
    assert_equal [ "maritime", "trade" ], marseille.themes
  end

  test "grouped_by_country returns country groups and cities sorted alphabetically" do
    asia = Continent.create!(name: "Asia", description: "Asian continent.")
    europe = Continent.create!(name: "Europe", description: "European continent.")

    japan = Country.create!(continent: asia, name: "Japan", description: "East Asia.")
    france = Country.create!(continent: europe, name: "France", description: "Western Europe.")

    City.create!(country: japan, name: "Tokyo", description: "Capital.", themes: [ "capital" ])
    City.create!(country: japan, name: "Osaka", description: "Commercial center.", themes: [ "commerce" ])
    City.create!(country: france, name: "Paris", description: "Capital.", themes: [ "capital" ])
    City.create!(country: france, name: "Lyon", description: "Gastronomy center.", themes: [ "culinary" ])

    groups = City.grouped_by_country
    assert_equal [ "Japan", "France" ], groups.map { |country, _| country.name }
    assert_equal [ "Osaka", "Tokyo" ], groups[0][1].map(&:name)
    assert_equal [ "Lyon", "Paris" ], groups[1][1].map(&:name)
  end

  test "destroying a country destroys its associated cities" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    france = Country.create!(continent: europe, name: "France", description: "Western Europe.")
    City.create!(country: france, name: "Paris", description: "Capital.", themes: [ "capital" ])

    assert_difference "City.count", -1 do
      france.destroy
    end
  end

  test "embedding_input formats city, country, continent, description, and themes" do
    continent = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: continent, name: "France", description: "French Republic.")
    city = City.new(
      country: country,
      name: "Paris",
      description: "Center of state power.",
      themes: [ "governance", "diplomacy" ]
    )

    expected = <<~TXT.strip
      City: Paris (France, Europe)
      Description: Center of state power.
      Themes: governance, diplomacy
    TXT

    assert_equal expected, city.embedding_input
  end
end
