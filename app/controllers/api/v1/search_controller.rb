# frozen_string_literal: true

module Api
  module V1
    class SearchController < BaseController
      def index
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        target_type = params[:target_type].to_s.downcase.presence || "all"
        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        countries_scope = Country.includes(:continent)
        cities_scope = City.includes(country: :continent)

        if (mode == "semantic" || mode == "auto") && (countries_scope.where.not(embedding: nil).exists? || cities_scope.where.not(embedding: nil).exists?)
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            country_results = []
            if %w[all country countries].include?(target_type)
              country_results = countries_scope.where.not(embedding: nil)
                                               .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                               .limit(limit)
                                               .map do |country|
                                                 {
                                                   type: "Country",
                                                   score: 1.0 - country.try(:neighbor_distance).to_f,
                                                   data: Serializer.country(country, neighbor_distance: country.try(:neighbor_distance))
                                                 }
                                               end
            end

            city_results = []
            if %w[all city cities].include?(target_type)
              city_results = cities_scope.where.not(embedding: nil)
                                         .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                         .limit(limit)
                                         .map do |city|
                                           {
                                             type: "City",
                                             score: 1.0 - city.try(:neighbor_distance).to_f,
                                             data: Serializer.city(city, neighbor_distance: city.try(:neighbor_distance))
                                           }
                                         end
            end

            combined = (country_results + city_results).sort_by { |item| -item[:score] }.take(limit)
            return render_success(combined, meta: { mode: "semantic", query: query, count: combined.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        # Keyword fallback
        country_kw = []
        if %w[all country countries].include?(target_type)
          country_kw = countries_scope.where("countries.name ILIKE :q OR countries.description ILIKE :q", q: "%#{query}%")
                                      .limit(limit)
                                      .map { |c| { type: "Country", data: Serializer.country(c) } }
        end

        city_kw = []
        if %w[all city cities].include?(target_type)
          city_kw = cities_scope.joins(:country)
                                .where("cities.name ILIKE :q OR cities.description ILIKE :q OR countries.name ILIKE :q", q: "%#{query}%")
                                .limit(limit)
                                .map { |c| { type: "City", data: Serializer.city(c) } }
        end

        combined = (country_kw + city_kw).take(limit)
        render_success(combined, meta: { mode: "keyword", query: query, count: combined.size })
      end
    end
  end
end
