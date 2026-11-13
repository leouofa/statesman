# frozen_string_literal: true

require "test_helper"

class CountryTest < ActiveSupport::TestCase
  test "validates presence of name, description, and continent" do
    country = Country.new(name: " ", description: " ")
    assert_not country.valid?
    assert_includes country.errors[:continent], "must exist"
    assert_includes country.errors[:name], "can't be blank"
    assert_includes country.errors[:description], "can't be blank"
  end

  test "normalizes name, description, and themes" do
    continent = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(
      continent: continent,
      name: "  France   Republic ",
      description: "  Western European state.  ",
      themes: [ " nuclear ", "Maritime", "NUCLEAR", "", nil ]
    )

    assert_equal "France Republic", country.name
    assert_equal "Western European state.", country.description
    assert_equal [ "nuclear", "Maritime" ], country.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    continent = Continent.create!(name: "Asia", description: "Asian continent.")
    country = Country.create!(
      continent: continent,
      name: "Japan",
      description: "East Asian island state.",
      themes: "island nation, industrial export, high tech, Island Nation"
    )

    assert_equal [ "island nation", "industrial export", "high tech" ], country.themes
  end

  test "enforces case-insensitive uniqueness scoped per continent" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    africa = Continent.create!(name: "Africa", description: "African continent.")

    Country.create!(continent: europe, name: "Georgia", description: "Transcaucasian state.")

    same_continent_dup = Country.new(continent: europe, name: "georgia", description: "Duplicate.")
    assert_not same_continent_dup.valid?
    assert_includes same_continent_dup.errors[:name], "has already been taken"

    other_continent_country = Country.new(continent: africa, name: "Georgia", description: "Different region.")
    assert other_continent_country.valid?
  end

  test "upsert_batch! inserts new countries and updates existing ones within a continent" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    asia = Continent.create!(name: "Asia", description: "Asian continent.")

    Country.create!(continent: europe, name: "France", description: "Old description", themes: [ "republic" ])
    Country.create!(continent: asia, name: "France", description: "Unrelated namesake", themes: [ "test" ])

    results = Country.upsert_batch!(europe, [
      { "name" => "  france ", "description" => "Fifth Republic.", "themes" => [ "republic", "nuclear power" ] },
      { "name" => "Germany", "description" => "Federal republic.", "themes" => [ "manufacturing", "export" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Italy", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, europe.countries.count
    assert_equal 1, asia.countries.count

    europe_france = europe.countries.find_by!("LOWER(name) = ?", "france")
    assert_equal "france", europe_france.name
    assert_equal "Fifth Republic.", europe_france.description
    assert_equal [ "republic", "nuclear power" ], europe_france.themes

    germany = europe.countries.find_by!(name: "Germany")
    assert_equal [ "manufacturing", "export" ], germany.themes
  end

  test "grouped_by_continent returns continent groups and countries sorted alphabetically" do
    asia = Continent.create!(name: "Asia", description: "Asian continent.")
    europe = Continent.create!(name: "Europe", description: "European continent.")
    Continent.create!(name: "Africa", description: "Empty continent.")

    Country.create!(continent: asia, name: "Japan", description: "East Asia.", themes: [ "island" ])
    Country.create!(continent: asia, name: "China", description: "East Asia.", themes: [ "manufacturing" ])
    Country.create!(continent: europe, name: "France", description: "Western Europe.", themes: [ "republic" ])
    Country.create!(continent: europe, name: "Germany", description: "Central Europe.", themes: [ "federal" ])

    groups = Country.grouped_by_continent
    assert_equal [ "Asia", "Europe" ], groups.map { |continent, _| continent.name }
    assert_equal [ "China", "Japan" ], groups[0][1].map(&:name)
    assert_equal [ "France", "Germany" ], groups[1][1].map(&:name)
  end

  test "destroying a continent destroys its associated countries" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    Country.create!(continent: europe, name: "France", description: "Western Europe.", themes: [ "republic" ])

    assert_difference("Country.count", -1) do
      europe.destroy!
    end
  end

  test "embedding_input formats continent, name, description, and themes" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "Western Europe state.", themes: [ "republic", "nuclear" ])

    expected = <<~TEXT.chomp
      Country: France (Europe)
      Description: Western Europe state.
      Themes: republic, nuclear
    TEXT

    assert_equal expected, country.embedding_input
    assert_not country.embedded?
  end
end
