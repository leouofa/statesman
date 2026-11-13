# frozen_string_literal: true

module Api
  module V1
    class ContinentsController < BaseController
      before_action :set_continent, only: %i[show update destroy populate_countries]

      def index
        scope = Continent.all
        scope = scope.where("name ILIKE :q OR description ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

        records, meta = paginate(scope.order("name ASC"))
        include_countries = boolean_param(:include_countries, default: false)

        data = records.map do |c|
          Serializer.continent(c, include_countries: include_countries)
        end

        render_success(data, meta: meta)
      end

      def show
        render_success(
          Serializer.continent(@continent, include_countries: boolean_param(:include_countries, default: true))
        )
      end

      def create
        continent = Continent.create!(continent_params)
        render_success(Serializer.continent(continent), status: :created)
      end

      def update
        @continent.update!(continent_params)
        render_success(Serializer.continent(@continent))
      end

      def destroy
        @continent.destroy!
        render_success({ id: @continent.id, name: @continent.name, deleted: true })
      end

      def populate_countries
        if sync_requested?
          result = PopulateCountriesJob.new.perform(continent_id: @continent.id)
          render_success({ message: "Countries populated for #{@continent.name}", result: result })
        else
          job = PopulateCountriesJob.perform_later(continent_id: @continent.id)
          render_success({ job_id: job.job_id, status: "queued", continent_id: @continent.id }, status: :accepted)
        end
      end

      def populate
        if sync_requested?
          result = PopulateContinentsJob.new.perform
          render_success({ message: "Continents populated", result: result })
        else
          job = PopulateContinentsJob.perform_later
          render_success({ job_id: job.job_id, status: "queued" }, status: :accepted)
        end
      end

      def upsert_batch
        entries = params.require(:continents).map do |entry|
          entry.permit(:name, :description).to_h
        end
        upserted = Continent.upsert_batch!(entries)
        render_success(
          upserted.map { |c| Serializer.continent(c) },
          meta: { count: upserted.size }
        )
      end

      private

      def set_continent
        @continent = Continent.find(params[:id])
      end

      def continent_params
        params.require(:continent).permit(:name, :description)
      end
    end
  end
end
