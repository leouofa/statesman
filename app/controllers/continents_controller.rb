# frozen_string_literal: true

class ContinentsController < ApplicationController
  def populate
    PopulateContinentsJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_controls",
            action_path: populate_continents_path,
            idle_label: "Populate Continents",
            running_label: "Discovering Continents...",
            running: true,
            status_message: "Asking the agent to discover all 7 continents...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to root_path, notice: "Asking the agent to discover all 7 continents..." }
    end
  end
end
