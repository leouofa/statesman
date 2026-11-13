# frozen_string_literal: true

module Api
  module V1
    class CitiesController < BaseController
      before_action :set_city, only: %i[show update destroy neighbors generate_embedding]

      def index
        scope = City.includes(country: :continent)
        scope = scope.where(country_id: params[:country_id]) if params[:country_id].present?
        if params[:continent_id].present?
          scope = scope.joins(:country).where(countries: { continent_id: params[:continent_id] })
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(cities.themes) elem WHERE elem ILIKE ?)", "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.joins(:country).where("cities.name ILIKE :q OR cities.description ILIKE :q OR countries.name ILIKE :q", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("cities.name ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        data = records.map do |city|
          Serializer.city(city, include_embedding: include_embedding, include_country: true)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = City.includes(country: :continent)
        scope = scope.where(country_id: params[:country_id]) if params[:country_id].present?
        if params[:continent_id].present?
          scope = scope.joins(:country).where(countries: { continent_id: params[:continent_id] })
        end

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |city|
              dist = city.try(:neighbor_distance)
              Serializer.city(city, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        keyword_matches = scope.joins(:country)
                               .where("cities.name ILIKE :q OR cities.description ILIKE :q OR countries.name ILIKE :q", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |c| Serializer.city(c) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.city(@city, include_embedding: boolean_param(:include_embedding, default: false), include_country: true)
        )
      end

      def create
        country = Country.find(params.require(:city).require(:country_id))
        city = country.cities.create!(city_params)
        render_success(Serializer.city(city), status: :created)
      end

      def update
        @city.update!(city_params)
        render_success(Serializer.city(@city))
      end

      def destroy
        @city.destroy!
        render_success({ id: @city.id, country_id: @city.country_id, deleted: true })
      end

      def neighbors
        unless @city.embedded?
          return render_error(code: "not_embedded", message: "City does not have an embedding yet")
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 100)
        scope = City.includes(country: :continent).where.not(id: @city.id)
        scope = scope.where(country_id: params[:country_id]) if params[:country_id].present?
        if params[:continent_id].present?
          scope = scope.joins(:country).where(countries: { continent_id: params[:continent_id] })
        end

        neighbors = scope.nearest_neighbors(:embedding, @city.embedding, distance: "cosine").limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.city(neighbor, neighbor_distance: neighbor.try(:neighbor_distance))
        end

        render_success(results, meta: { city_id: @city.id, count: results.size })
      end

      def generate_embedding
        if sync_requested?
          @city.generate_embedding!
          render_success(Serializer.city(@city, include_embedding: boolean_param(:include_embedding, default: false)))
        else
          job = GenerateEmbeddingJob.perform_later("City", @city.id)
          render_success({ job_id: job.job_id, status: "queued", city_id: @city.id }, status: :accepted)
        end
      end

      def populate
        country_id = params[:country_id].presence
        if sync_requested?
          result = PopulateCitiesJob.new.perform(country_id: country_id)
          render_success({ message: "Cities populated", result: result })
        else
          job = PopulateCitiesJob.perform_later(country_id: country_id)
          render_success({ job_id: job.job_id, status: "queued", country_id: country_id }, status: :accepted)
        end
      end

      def upsert_batch
        country = Country.find(params.require(:country_id))
        entries = params.require(:cities).map do |entry|
          entry.permit(:name, :description, themes: []).to_h
        end
        upserted = City.upsert_batch!(country, entries)
        render_success(
          upserted.map { |c| Serializer.city(c) },
          meta: { country_id: country.id, count: upserted.size }
        )
      end

      private

      def set_city
        @city = City.includes(country: :continent).find(params[:id])
      end

      def city_params
        p = params.require(:city).permit(:country_id, :name, :description, themes: [])
        p[:themes] = City.normalize_themes(p[:themes]) if p.key?(:themes)
        p
      end
    end
  end
end
