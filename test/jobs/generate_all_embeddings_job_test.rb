# frozen_string_literal: true

require "test_helper"

class GenerateAllEmbeddingsJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "perform with only_missing: true skips already-embedded countries and embeds missing ones" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    existing_vector = Array.new(1024, 0.1)
    france = Country.create!(
      continent: europe,
      name: "France",
      description: "French Republic.",
      embedding: existing_vector,
      embedding_model: "old-model",
      embedded_at: 1.day.ago
    )
    germany = Country.create!(continent: europe, name: "Germany", description: "Federal Republic.")

    new_vector = Array.new(1024, 0.2)
    called_texts = []

    with_stubbed_generator(->(text) {
      called_texts << text
      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 2) do
        GenerateAllEmbeddingsJob.perform_now("Country", only_missing: true)
      end
    end

    assert_equal 1, called_texts.size
    assert_match "Germany", called_texts.first
    assert_equal "old-model", france.reload.embedding_model
    assert_equal "qwen3-embedding:0.6b", germany.reload.embedding_model
  end

  test "perform with only_missing: false regenerates all cities" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    france = Country.create!(continent: europe, name: "France", description: "French Republic.")
    germany = Country.create!(continent: europe, name: "Germany", description: "Federal Republic.")

    city1 = City.create!(
      country: france,
      name: "Paris",
      description: "National capital.",
      themes: [ "capital" ],
      embedding: Array.new(1024, 0.1),
      embedding_model: "old-model",
      embedded_at: 1.day.ago
    )
    city2 = City.create!(country: germany, name: "Berlin", description: "Federal capital.", themes: [ "capital" ])

    new_vector = Array.new(1024, 0.3)
    called_count = 0

    with_stubbed_generator(->(_text) {
      called_count += 1
      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 3) do
        GenerateAllEmbeddingsJob.perform_now("City", only_missing: false)
      end
    end

    assert_equal 2, called_count
    assert_equal "qwen3-embedding:0.6b", city1.reload.embedding_model
    assert_equal "qwen3-embedding:0.6b", city2.reload.embedding_model
  end

  test "perform continues remaining records when one record fails" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    france = Country.create!(continent: europe, name: "France", description: "French Republic.")
    germany = Country.create!(continent: europe, name: "Germany", description: "Federal Republic.")

    new_vector = Array.new(1024, 0.4)

    with_stubbed_generator(->(text) {
      raise "Temporary timeout" if text.include?("France")

      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 3) do
        GenerateAllEmbeddingsJob.perform_now("Country", only_missing: true)
      end
    end

    assert_not france.reload.embedded?
    assert germany.reload.embedded?
  end

  test "perform broadcasts info message when nothing needs embedding" do
    assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 1) do
      GenerateAllEmbeddingsJob.perform_now("Country", only_missing: true)
    end
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
