# frozen_string_literal: true

class CityDiscoveryAgent < ApplicationAgent
  inputs :country_name, :country_description, :country_themes, :continent_name, :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing city names already in our database for this country: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same cities so records update cleanly without duplicates, " \
          "and include any missing key cities as well."
      else
        "Identify 8 to 10 major, strategically prominent, or economically vital cities across this country."
      end

    themes_list = Array(country_themes).compact_blank
    themes_clause = themes_list.any? ? "Country thematic tags: #{themes_list.join(', ')}." : ""
    desc_clause = country_description.present? ? "Country context: #{country_description}" : ""

    <<~INSTRUCTIONS.squish
      You are an expert scholar of urban geography, political economy, and civic statecraft.
      Identify 8 to 10 major, economically central, or strategically vital cities in #{country_name} (#{continent_name}).
      Ensure representation of the national capital, primary commercial/financial hubs, major maritime or river ports, manufacturing or technological centers, and key regional anchors.
      #{desc_clause}
      #{themes_clause}
      #{existing_clause}

      For each city, provide:
      1. Its canonical city name.
      2. A concise, informative description covering its civic and institutional role, economic base, strategic geography, and urban character.
      3. A JSON array of 2 to 6 concise thematic tags as lowercase strings (e.g., ["national capital", "deepwater port", "financial center", "manufacturing hub"]).

      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"cities":[{"name":"Marseille","description":"Major Mediterranean port and commercial gateway with historical trade networks and petrochemical logistics.","themes":["deepwater port","mediterranean gateway","logistics hub"]}]}
    INSTRUCTIONS
  end
end
