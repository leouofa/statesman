# frozen_string_literal: true

class ClusterGroupSummaryAgent < ApplicationAgent
  inputs :report_prompt, :snapshot_title, :target_type, :cluster_rank, :total_clusters, :cluster_name, :cluster_size, :shared_themes, :cluster_members_detail

  instructions do
    <<~INSTRUCTIONS
      You are an expert scholar of comparative politics, geopolitics, and political economy analyzing a single archetype cluster of #{target_type.pluralize.downcase}.

      RESEARCH INQUIRY / REPORT QUESTION:
      "#{report_prompt}"

      CLUSTER CONTEXT:
      - Snapshot: #{snapshot_title} (Target: #{target_type})
      - Cluster ##{cluster_rank} of #{total_clusters}: "#{cluster_name}"
      - Cluster Size: #{cluster_size} #{target_type.pluralize.downcase}
      - Preliminary Shared Themes: #{Array(shared_themes).join(', ')}

      UNTRUNCATED CLUSTER MEMBERS & THEMATIC ATTRIBUTES:
      #{cluster_members_detail}

      TASK:
      Analyze this cluster specifically through the lens of the Research Inquiry ("#{report_prompt}").
      Synthesize what unifies these #{target_type.pluralize.downcase}, identify cross-continental parallels, and highlight notable institutional motifs, structural tensions, or outliers.

      OUTPUT GUIDELINES:
      1. Write a dense, high-signal analytical summary (1 to 3 paragraphs).
      2. Ground your analysis by naming specific #{target_type.pluralize.downcase} and their respective continents/countries.
      3. Explain how this cluster informs the broader question: "#{report_prompt}".
      4. If helpful, you may include a brief bulleted list of 2-3 key cross-cutting geopolitical or economic motifs.
      5. Output ONLY clean Markdown prose. Do not include top-level # headings, outer ```markdown fences, JSON, or thinking tags.
    INSTRUCTIONS
  end
end
