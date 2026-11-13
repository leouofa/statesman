# frozen_string_literal: true

require "test_helper"

class SnapshotDigestBuilderTest < ActiveSupport::TestCase
  test "builds digest for Country snapshot" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country1 = Country.create!(continent: europe, name: "France", description: "Western European republic.", themes: [ "republic", "nuclear" ])
    country2 = Country.create!(continent: europe, name: "Germany", description: "Central European federal state.", themes: [ "federal", "manufacturing" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "Country",
      level: 5,
      distance_threshold: 0.20,
      title: "European Powers",
      clusters_count: 1,
      items_count: 2
    )

    group = snapshot.cluster_groups.create!(name: "Continental Heavyweights", shared_themes: [ "federal", "republic" ], size: 2)
    group.cluster_memberships.create!(record: country1)
    group.cluster_memberships.create!(record: country2)

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, max_chars: 10_000)

    assert_includes digest, "=== CLUSTER SNAPSHOT OVERVIEW ==="
    assert_includes digest, "European Powers"
    assert_includes digest, "Target Type: Country"
    assert_includes digest, "Continental Heavyweights"
    assert_includes digest, "France (Europe)"
    assert_includes digest, "Germany (Europe)"
  end

  test "builds digest for City snapshot" do
    europe = Continent.create!(name: "Europe", description: "European continent.")
    country = Country.create!(continent: europe, name: "France", description: "Western European republic.")
    city = City.create!(country: country, name: "Marseille", description: "Mediterranean port gateway.", themes: [ "port", "trade" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "City",
      level: 10,
      distance_threshold: 0.25,
      title: "City Clusters",
      clusters_count: 1,
      items_count: 1
    )

    group = snapshot.cluster_groups.create!(name: "Maritime Trade Gateways", shared_themes: [ "port" ], size: 1)
    group.cluster_memberships.create!(record: city)

    report = snapshot.cluster_reports.create!(prompt: "Analyze trade hubs")
    report.cluster_report_summaries.create!(
      cluster_group: group,
      content: "This cluster focuses on sovereign deepwater ports and trade logistics.",
      position: 1
    )

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, report: report, max_chars: 5_000)

    assert_includes digest, "Target Type: City"
    assert_includes digest, "Marseille (France, Europe)"
    assert_includes digest, "Mediterranean port gateway"
    assert_includes digest, "Prompt-Guided Cluster Analysis:"
    assert_includes digest, "sovereign deepwater ports and trade logistics"
  end
end
