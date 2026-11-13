# frozen_string_literal: true

require "test_helper"

class EmbeddingClustererTest < ActiveSupport::TestCase
  test "handles empty target with zero embeddings" do
    result = Clustering::EmbeddingClusterer.call(City, level: 5, force: true)
    assert_equal "Cities", result.target_name
    assert_equal 0, result.total_embedded_count
    assert_empty result.clusters
    assert_empty result.singletons
  end

  test "clamps level within 1 to 15" do
    result_low = Clustering::EmbeddingClusterer.new(Country, level: -5)
    assert_equal 1, result_low.instance_variable_get(:@level)

    result_high = Clustering::EmbeddingClusterer.new(Country, level: 99)
    assert_equal 15, result_high.instance_variable_get(:@level)
  end

  test "full_coverage absorbs singletons so unclustered count is zero" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    v1 = Array.new(1024, 0.1)
    v2 = Array.new(1024, 0.1) # pair
    v3 = Array.new(1024, 0.5) # singleton

    Country.create!(continent: europe, name: "Country 1", description: "D1", themes: [ "republic" ], embedding: v1)
    Country.create!(continent: europe, name: "Country 2", description: "D2", themes: [ "republic" ], embedding: v2)
    Country.create!(continent: europe, name: "Country 3", description: "D3", themes: [ "monarchy" ], embedding: v3)

    result = Clustering::EmbeddingClusterer.call(Country, level: 5, full_coverage: true, force: true)
    assert_equal 0, result.singletons_count
    assert result.full_coverage?
  end

  test "clusters embedded countries and supports saving snapshots" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    v1 = Array.new(1024, 0.1)
    v2 = Array.new(1024, 0.1) # identical to v1, distance = 0
    v3 = Array.new(1024, -0.1) # opposite vector, distance ~ 2.0

    c1 = Country.create!(continent: europe, name: "Country 1", description: "D1", themes: [ "republic" ], embedding: v1)
    c2 = Country.create!(continent: europe, name: "Country 2", description: "D2", themes: [ "republic" ], embedding: v2)
    c3 = Country.create!(continent: europe, name: "Country 3", description: "D3", themes: [ "monarchy" ], embedding: v3)

    result = Clustering::EmbeddingClusterer.call(Country, level: 5, force: true)
    assert_operator result.total_embedded_count, :>=, 3

    # c1 and c2 must be in the same cluster because distance is 0
    target_cluster = result.clusters.find { |c| c.records.map(&:id).include?(c1.id) }
    assert_not_nil target_cluster
    assert_includes target_cluster.records.map(&:id), c2.id

    # Test snapshotting
    assert_difference("ClusterSnapshot.count", 1) do
      snapshot = result.snapshot!(title: "Integration Test Snapshot")
      assert_equal "Country", snapshot.target_type
      assert_operator snapshot.cluster_groups.count, :>=, 1
    end
  end
end
