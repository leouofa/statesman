# frozen_string_literal: true

require "test_helper"

class HeuristicLabelerTest < ActiveSupport::TestCase
  test "labels an empty list of records" do
    result = Clustering::HeuristicLabeler.label([])
    assert_equal "Empty Cluster", result[:title]
    assert_empty result[:shared_themes]
  end

  test "extracts shared themes and builds archetype title for countries" do
    continent = Continent.create!(name: "Europe", description: "European continent.")
    c1 = Country.create!(continent: continent, name: "France", description: "Western Europe", themes: %w[nuclear maritime republic])
    c2 = Country.create!(continent: continent, name: "United Kingdom", description: "Island state", themes: %w[nuclear maritime monarchy])

    result = Clustering::HeuristicLabeler.label([ c1, c2 ])
    assert_includes result[:shared_themes], "Nuclear"
    assert_includes result[:shared_themes], "Maritime"
    assert_includes result[:title], "Archetype"
  end

  test "extracts shared themes for cities" do
    continent = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: continent, name: "France", description: "Western Europe")
    city1 = City.create!(country: country, name: "Marseille", description: "Port", themes: [ "port", "trade" ])
    city2 = City.create!(country: country, name: "Le Havre", description: "Northern port", themes: [ "port", "logistics" ])

    result = Clustering::HeuristicLabeler.label([ city1, city2 ])
    assert_includes result[:shared_themes], "Port"
    assert_includes result[:title], "Archetype"
  end
end
