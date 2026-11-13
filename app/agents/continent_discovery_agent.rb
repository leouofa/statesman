# frozen_string_literal: true

class ContinentDiscoveryAgent < ApplicationAgent
  inputs :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing continent names already in our database: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same continents so records update cleanly without duplicates, " \
          "and include any missing continents as well."
      else
        "Include all 7 standard continents: Africa, Antarctica, Asia, Europe, North America, Oceania, South America."
      end

    <<~INSTRUCTIONS.squish
      You are an expert scholar of comparative politics, geopolitics, and international relations.
      Identify all 7 world continents: Africa, Antarctica, Asia, Europe, North America, Oceania, South America.
      For each continent, provide its canonical name and a concise, high-signal description covering its strategic geography, geopolitical significance, major institutional architectures, and political-economic landscape.
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"continents":[{"name":"Europe","description":"..."}]}
    INSTRUCTIONS
  end
end
