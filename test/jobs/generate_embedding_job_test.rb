# frozen_string_literal: true

require "test_helper"

class GenerateEmbeddingJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "perform generates embedding for Country and broadcasts running and success states" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "French Republic.", themes: [ "republic", "nuclear" ])
    vector = Array.new(1024, 0.05)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(country), 2) do
        GenerateEmbeddingJob.perform_now("Country", country.id)
      end
    end

    country.reload
    assert country.embedded?
    assert_equal "qwen3-embedding:0.6b", country.embedding_model
    assert_not_nil country.embedded_at
    assert_equal 1024, country.embedding.size
  end

  test "perform generates embedding for City and broadcasts running and success states" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "French Republic.", themes: [ "republic" ])
    city = City.create!(country: country, name: "Paris", description: "Capital city.", themes: [ "capital" ])
    vector = Array.new(1024, 0.02)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(city), 2) do
        GenerateEmbeddingJob.perform_now("City", city.id)
      end
    end

    city.reload
    assert city.embedded?
    assert_equal "qwen3-embedding:0.6b", city.embedding_model
    assert_not_nil city.embedded_at
    assert_equal 1024, city.embedding.size
  end

  test "perform broadcasts error state when embedding generation fails" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "Germany", description: "Federal Republic.")

    with_stubbed_generator(->(_text) { raise "Connection refused" }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(country), 2) do
        GenerateEmbeddingJob.perform_now("Country", country.id)
      end
    end

    assert_not country.reload.embedded?
  end

  private

  def with_stubbed_generator(replacement)
    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call, &replacement)
    yield
  ensure
    singleton.define_method(:call, original)
  end
end
