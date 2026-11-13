# frozen_string_literal: true

require "test_helper"
require "ostruct"

class Llm::JsonResponseParserTest < ActiveSupport::TestCase
  test "extract_list prefers response.parsed when present" do
    response = OpenStruct.new(parsed: { "countries" => [ { "name" => "France" } ] }, content: "ignored")
    assert_equal [ { "name" => "France" } ], Llm::JsonResponseParser.extract_list(response, key: "countries")
  end

  test "extract_list strips think tags and markdown fences" do
    response = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Thinking about sovereign states...</think>
        ```json
        { "countries": [{ "name": "Germany", "themes": ["federal"] }] }
        ```
      TEXT
    )

    assert_equal [ { "name" => "Germany", "themes" => [ "federal" ] } ],
                 Llm::JsonResponseParser.extract_list(response, key: "countries")
  end

  test "extract_list falls back to embedded JSON and returns empty array for invalid text" do
    embedded_array = OpenStruct.new(parsed: nil, content: "Here is the list: [{\"name\":\"Japan\"}] Hope that helps!")
    assert_equal [ { "name" => "Japan" } ], Llm::JsonResponseParser.extract_list(embedded_array, key: "countries")

    embedded_object = OpenStruct.new(parsed: nil, content: "[Note] {\"countries\":[{\"name\":\"Brazil\"}]} Done.")
    assert_equal [ { "name" => "Brazil" } ], Llm::JsonResponseParser.extract_list(embedded_object, key: "countries")

    invalid = OpenStruct.new(parsed: nil, content: "Not JSON at all")
    assert_equal [], Llm::JsonResponseParser.extract_list(invalid, key: "countries")
  end

  test "extract_hash parses flat JSON objects and unwraps optional nested key" do
    flat = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Analyzing statecraft themes...</think>
        ```json
        {
          "Maritime Trade Network": "Control of key shipping lanes and deepwater ports.",
          "Industrial Export Base": "High-value manufacturing and technology supply chains."
        }
        ```
      TEXT
    )

    assert_equal(
      {
        "Maritime Trade Network" => "Control of key shipping lanes and deepwater ports.",
        "Industrial Export Base" => "High-value manufacturing and technology supply chains."
      },
      Llm::JsonResponseParser.extract_hash(flat, key: "themes")
    )

    wrapped = OpenStruct.new(
      parsed: { "themes" => { "Sovereignty" => "Constitutional governance." } },
      content: "ignored"
    )
    assert_equal({ "Sovereignty" => "Constitutional governance." }, Llm::JsonResponseParser.extract_hash(wrapped, key: "themes"))

    invalid = OpenStruct.new(parsed: nil, content: "No JSON object here")
    assert_equal({}, Llm::JsonResponseParser.extract_hash(invalid, key: "themes"))
  end
end
