# frozen_string_literal: true

module Clustering
  # Serializes clusters in a ClusterSnapshot into a rich, structured,
  # token-budget-aware text digest for comparative LLM reporting.
  # Can embed prompt-guided ClusterReportSummary records when available.
  class SnapshotDigestBuilder
    DEFAULT_MAX_CHARS = 120_000

    def self.call(snapshot, report: nil, max_chars: nil)
      budget = max_chars || Llm::ModelRegistry.digest_char_budget
      new(snapshot, report: report, max_chars: budget).call
    end

    def self.format_full_group_detail(group, target_type:, max_chars: 50_000)
      memberships = group.cluster_memberships.to_a
      return "  (none)" if memberships.empty?

      lines = []
      memberships.each_with_index do |m, idx|
        record = m.record
        next unless record

        lines << case target_type
        when "Country"
          format_full_country_member(record, idx + 1)
        when "City"
          format_full_city_member(record, idx + 1)
        else
          "#{idx + 1}. Record ##{record.id}"
        end
      end

      full_text = lines.join("\n\n")
      if full_text.length > max_chars
        full_text.truncate(max_chars, omission: "\n\n... [Remaining members truncated to fit cluster analysis budget] ...")
      else
        full_text
      end
    end

    def initialize(snapshot, report: nil, max_chars: DEFAULT_MAX_CHARS)
      @snapshot = snapshot
      @report = report
      @max_chars = max_chars
    end

    def call
      groups = @snapshot.cluster_groups.by_size.includes(cluster_memberships: eager_associations)
      target_type = @snapshot.target_type

      # Preload report summaries if report is given
      summaries_by_group_id = if @report.present?
        @report.cluster_report_summaries.index_by(&:cluster_group_id)
      else
        {}
      end

      # Compute overall continent coverage
      continent_counts = Hash.new(0)
      groups.each do |group|
        group.cluster_memberships.each do |m|
          record = m.record
          next unless record

          c_name = record_continent_name(record)
          continent_counts[c_name] += 1 if c_name.present?
        end
      end

      top_continents = continent_counts.sort_by { |_, c| -c }.first(12)
        .map { |name, count| "#{name} (#{count})" }.join(", ")

      header = <<~HEADER
        === CLUSTER SNAPSHOT OVERVIEW ===
        Title: #{@snapshot.title}
        Target Type: #{target_type}
        Clustering Level: #{@snapshot.level} (distance threshold <= #{@snapshot.distance_threshold})
        Total Clusters: #{@snapshot.clusters_count}
        Total Persisted Items: #{@snapshot.items_count}
        Represented Continents: #{top_continents}
        Generated At: #{@snapshot.created_at.strftime('%Y-%m-%d %H:%M UTC')}
        Prompt-Guided Cluster Summaries Included: #{summaries_by_group_id.any? ? "Yes (#{summaries_by_group_id.size}/#{groups.size})" : "No"}
        =================================

        CLUSTERS (#{groups.size} total):
      HEADER

      char_budget_remaining = @max_chars - header.length
      cluster_blocks = []

      # Allocate per-cluster member details budget
      budget_per_group = [ (char_budget_remaining / [ groups.size, 1 ].max).to_i, 500 ].max

      groups.each_with_index do |group, idx|
        summary = summaries_by_group_id[group.id]
        cluster_blocks << format_cluster(
          group,
          rank: idx + 1,
          target_type: target_type,
          summary: summary,
          member_budget: budget_per_group
        )
      end

      full_digest = ([ header.strip ] + cluster_blocks).join("\n\n")
      if full_digest.length > @max_chars
        full_digest.truncate(@max_chars, omission: "\n\n... [Digest truncated to fit context budget] ...")
      else
        full_digest
      end
    end

    private

    def eager_associations
      case @snapshot.target_type
      when "Country"
        { record: :continent }
      when "City"
        { record: { country: :continent } }
      else
        :record
      end
    end

    def record_continent_name(record)
      case record
      when Country then record.continent&.name
      when City then record.country&.continent&.name
      end
    end

    def format_cluster(group, rank:, target_type:, summary:, member_budget:)
      # Continent distribution in this cluster
      group_continents = Hash.new(0)
      memberships = group.cluster_memberships.to_a

      memberships.each do |m|
        next unless m.record

        c_name = record_continent_name(m.record)
        group_continents[c_name] += 1 if c_name.present?
      end

      continent_dist = group_continents.sort_by { |_, c| -c }
        .map { |name, count| "#{name}: #{count}" }.join(", ")

      themes_str = group.shared_themes.presence ? group.shared_themes.join(", ") : "None specified"

      lines = [
        "### Cluster ##{rank}: \"#{group.name}\"",
        "Size: #{group.size} #{target_type.pluralize.downcase}",
        "Dominant Continents: #{continent_dist.presence || 'None'}",
        "Shared Themes: #{themes_str}"
      ]

      if summary.present? && summary.content.present?
        lines << "Prompt-Guided Cluster Analysis:"
        lines << summary.content.strip
      end

      lines << "Members:"
      members_text = format_members(memberships, target_type: target_type, budget: member_budget)
      lines << members_text

      lines.join("\n")
    end

    def format_members(memberships, target_type:, budget:)
      return "  (none)" if memberships.empty?

      member_lines = []
      used_chars = 0

      memberships.each_with_index do |m, idx|
        record = m.record
        next unless record

        line = case target_type
        when "Country"
          format_country_member(record)
        when "City"
          format_city_member(record)
        else
          "  - #{record.id}"
        end

        if used_chars + line.length > budget && idx < memberships.size - 1
          remaining = memberships.size - idx
          member_lines << "  - ... and #{remaining} more #{target_type.pluralize.downcase}"
          break
        end

        member_lines << line
        used_chars += line.length
      end

      member_lines.join("\n")
    end

    def format_country_member(country)
      continent_name = country.continent&.name || "Unknown"
      themes_str = country.themes.presence ? " [themes: #{country.themes.first(4).join(', ')}]" : ""
      desc_snippet = country.description.to_s.squish.truncate(100)
      "  - #{country.name} (#{continent_name})#{themes_str}: #{desc_snippet}"
    end

    def format_city_member(city)
      country_name = city.country&.name || "Unknown Country"
      continent_name = city.country&.continent&.name || "Unknown Continent"
      themes_str = city.themes.presence ? " [themes: #{city.themes.first(4).join(', ')}]" : ""
      desc_snippet = city.description.to_s.squish.truncate(100)

      "  - #{city.name} (#{country_name}, #{continent_name})#{themes_str}: #{desc_snippet}"
    end

    def self.format_full_country_member(country, index)
      continent_name = country.continent&.name || "Unknown"
      themes_str = country.themes.presence ? country.themes.join(", ") : "None"
      <<~COUNTRY.strip
        [#{index}] #{country.name} (#{continent_name})
        Themes: #{themes_str}
        Description: #{country.description}
      COUNTRY
    end

    def self.format_full_city_member(city, index)
      country_name = city.country&.name || "Unknown Country"
      continent_name = city.country&.continent&.name || "Unknown Continent"
      themes_str = city.themes.presence ? city.themes.join(", ") : "None"

      <<~CITY.strip
        [#{index}] #{city.name} (#{country_name}, #{continent_name})
        Themes: #{themes_str}
        Description: #{city.description}
      CITY
    end
  end
end
