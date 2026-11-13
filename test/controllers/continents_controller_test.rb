# frozen_string_literal: true

require "test_helper"

class ContinentsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateContinentsJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateContinentsJob) do
      post populate_continents_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Continents...", response.body
  end

  test "populate enqueues PopulateContinentsJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateContinentsJob) do
      post populate_continents_url
    end

    assert_redirected_to root_url
  end
end
