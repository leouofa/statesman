# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    @continents = Continent.ordered
  end

  def countries
    @continent_groups = Country.grouped_by_continent
    @total_countries_count = Country.count
    @continents_count = Continent.count
  end

  def cities
    @country_groups = City.grouped_by_country
    @total_cities_count = City.count
    @countries_count = Country.count
  end
end
