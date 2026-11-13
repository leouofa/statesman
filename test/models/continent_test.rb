# frozen_string_literal: true

require "test_helper"

class ContinentTest < ActiveSupport::TestCase
  test "validates presence of name and description" do
    continent = Continent.new(name: " ", description: " ")
    assert_not continent.valid?
    assert_includes continent.errors[:name], "can't be blank"
    assert_includes continent.errors[:description], "can't be blank"
  end

  test "normalizes name whitespace and enforces case-insensitive uniqueness" do
    first = Continent.create!(name: "  North   America ", description: "Northern continent.")
    assert_equal "North America", first.name

    duplicate = Continent.new(name: "north america", description: "Duplicate.")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "identifies antarctica" do
    antarctica = Continent.create!(name: "Antarctica", description: "Southern polar continent.")
    assert antarctica.antarctica?

    europe = Continent.create!(name: "Europe", description: "Eurasian western subcontinent.")
    assert_not europe.antarctica?
  end

  test "upsert_batch! inserts new continents and updates existing ones case-insensitively" do
    Continent.create!(name: "Europe", description: "Old description")

    results = Continent.upsert_batch!([
      { "name" => "  europe ", "description" => "Updated European continent." },
      { "name" => "Asia", "description" => "Largest world continent." },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Africa", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, Continent.count

    europe = Continent.find_by!("LOWER(name) = ?", "europe")
    assert_equal "europe", europe.name
    assert_equal "Updated European continent.", europe.description

    asia = Continent.find_by!(name: "Asia")
    assert_equal "Largest world continent.", asia.description
  end
end
