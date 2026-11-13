# frozen_string_literal: true

module Api
  module V1
    class CountriesController < BaseController
      before_action :set_country, only: %i[show update destroy neighbors generate_embedding populate_cities]

      def index
        scope = Country.includes(:continent)
        scope = scope.where(continent_id: params[:continent_id]) if params[:continent_id].present?
        if params[:continent].present?
          scope = scope.joins(:continent).where("continents.name ILIKE ?", "%#{params[:continent]}%")
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(countries.themes) elem WHERE elem ILIKE ?)", "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.where("countries.name ILIKE :q OR countries.description ILIKE :q", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("countries.name ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        include_cities = boolean_param(:include_cities, default: false)

        data = records.map do |c|
          Serializer.country(c, include_embedding: include_embedding, include_cities: include_cities)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = Country.includes(:continent)
        scope = scope.where(continent_id: params[:continent_id]) if params[:continent_id].present?

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |country|
              dist = country.try(:neighbor_distance)
              Serializer.country(country, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        keyword_matches = scope.where("countries.name ILIKE :q OR countries.description ILIKE :q", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |country| Serializer.country(country) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.country(
            @country,
            include_embedding: boolean_param(:include_embedding, default: false),
            include_cities: boolean_param(:include_cities, default: true)
          )
        )
      end

      def create
        country = Country.create!(country_params)
        render_success(Serializer.country(country), status: :created)
      end

      def update
        @country.update!(country_params)
        render_success(Serializer.country(@country))
      end

      def destroy
        @country.destroy!
        render_success({ id: @country.id, name: @country.name, deleted: true })
      end

      def neighbors
        unless @country.embedded?
          return render_error(code: "not_embedded", message: "Country '#{@country.name}' does not have an embedding yet")
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 100)
        scope = Country.includes(:continent).where.not(id: @country.id)
        scope = scope.where(continent_id: params[:continent_id]) if params[:continent_id].present?

        neighbors = scope.nearest_neighbors(:embedding, @country.embedding, distance: "cosine").limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.country(neighbor, neighbor_distance: neighbor.try(:neighbor_distance))
        end

        render_success(results, meta: { country_id: @country.id, count: results.size })
      end

      def generate_embedding
        if sync_requested?
          @country.generate_embedding!
          render_success(Serializer.country(@country, include_embedding: boolean_param(:include_embedding, default: false)))
        else
          job = GenerateEmbeddingJob.perform_later("Country", @country.id)
          render_success({ job_id: job.job_id, status: "queued", country_id: @country.id }, status: :accepted)
        end
      end

      def populate_cities
        if sync_requested?
          result = PopulateCitiesJob.new.perform(country_id: @country.id)
          render_success({ message: "Cities populated for #{@country.name}", result: result })
        else
          job = PopulateCitiesJob.perform_later(country_id: @country.id)
          render_success({ job_id: job.job_id, status: "queued", country_id: @country.id }, status: :accepted)
        end
      end

      def populate
        continent_id = params[:continent_id].presence
        if sync_requested?
          result = PopulateCountriesJob.new.perform(continent_id: continent_id)
          render_success({ message: "Countries populated", result: result })
        else
          job = PopulateCountriesJob.perform_later(continent_id: continent_id)
          render_success({ job_id: job.job_id, status: "queued", continent_id: continent_id }, status: :accepted)
        end
      end

      def upsert_batch
        continent = Continent.find(params.require(:continent_id))
        entries = params.require(:countries).map do |entry|
          entry.permit(:name, :description, themes: []).to_h
        end
        upserted = Country.upsert_batch!(continent, entries)
        render_success(
          upserted.map { |c| Serializer.country(c) },
          meta: { continent_id: continent.id, count: upserted.size }
        )
      end

      private

      def set_country
        @country = Country.includes(:continent, :cities).find(params[:id])
      end

      def country_params
        p = params.require(:country).permit(:continent_id, :name, :description, themes: [])
        p[:themes] = Country.normalize_themes(p[:themes]) if p.key?(:themes)
        p
      end
    end
  end
end
