# frozen_string_literal: true

class CountryDiscoveryAgent < ApplicationAgent
  inputs :continent_name, :continent_description, :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing country names already in our database for this continent: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same countries so records update cleanly without duplicates, " \
          "and include any missing sovereign states from this continent as well."
      else
        "Use clear, canonical state names (e.g., 'France', 'Japan', 'Brazil', 'Nigeria')."
      end

    context_clause = continent_description.present? ? "Continent context: #{continent_description}" : ""

    <<~INSTRUCTIONS.squish
      You are an expert scholar of comparative politics, statecraft, and political economy.
      Identify all sovereign states belonging to #{continent_name}.
      Note: If the continent is Antarctica, return an empty countries array {"countries":[]} since Antarctica has no sovereign states.
      #{context_clause}
      For each sovereign state, provide:
      1. Its canonical common name.
      2. A concise, informative description covering its institutional structure, strategic geography, economic model, and historical statecraft trajectory.
      3. A JSON array of 2 to 6 concise thematic tags as lowercase strings (e.g., ["parliamentary democracy", "maritime trade", "industrial export", "resource sovereign"]).
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"countries":[{"name":"France","description":"...","themes":["semi-presidential republic","maritime power","nuclear energy"]}]}
    INSTRUCTIONS
  end
end
