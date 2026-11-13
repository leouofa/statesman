# frozen_string_literal: true

class ClusterBatchSummaryAgent < ApplicationAgent
  inputs :report_prompt, :snapshot_title, :target_type, :batch_index, :total_batches, :cluster_count, :batch_digest

  instructions do
    <<~INSTRUCTIONS
      You are an expert scholar of comparative politics, geopolitics, and political economy performing a mid-level aggregation pass over a corpus of #{target_type.pluralize.downcase}.

      RESEARCH INQUIRY / REPORT QUESTION:
      "#{report_prompt}"

      BATCH CONTEXT:
      - Snapshot: #{snapshot_title} (Target: #{target_type})
      - This is batch ##{batch_index} of #{total_batches}, covering #{cluster_count} archetype #{cluster_count == 1 ? 'cluster' : 'clusters'}.

      CLUSTER SUMMARIES IN THIS BATCH:
      #{batch_digest}

      TASK:
      Aggregate the cluster analyses above into a single coherent mid-level narrative that serves as an intermediate layer before the final deep synthesis. Your narrative is the bridge between per-cluster detail and the final report, so it MUST preserve the specifics a final report will need to cite.

      OUTPUT GUIDELINES:
      1. Write 2 to 4 dense, high-signal paragraphs (plus an optional 2-3 item bulleted list of cross-cutting geopolitical/economic motifs).
      2. PRESERVE concrete specifics: reference cluster numbers (e.g. "Cluster #3: ...") and name specific #{target_type.pluralize.downcase} and their continents/countries.
      3. Compress member enumerations, NOT analytical themes: keep cross-continental parallels, institutional models, trade flows, structural tensions, and surprising connections.
      4. Explicitly connect the batch's findings back to the Research Inquiry: "#{report_prompt}".
      5. Output ONLY clean Markdown prose. Do not include top-level # headings, outer ```markdown fences, JSON, or thinking tags.
    INSTRUCTIONS
  end
end
