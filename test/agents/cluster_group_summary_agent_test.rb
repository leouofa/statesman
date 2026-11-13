# frozen_string_literal: true

require "test_helper"

class ClusterGroupSummaryAgentTest < ActiveSupport::TestCase
  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end

    Llm::ModelRegistry.ensure_configured_model!(model_id: @model_id)
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "create! sets prompt instructions and untruncated member detail correctly" do
    chat = ClusterGroupSummaryAgent.create!(
      report_prompt: "Find patterns in maritime gateway states",
      snapshot_title: "Countries Snapshot",
      target_type: "Country",
      cluster_rank: 1,
      total_clusters: 10,
      cluster_name: "Maritime Trade and Naval Power",
      cluster_size: 4,
      shared_themes: [ "maritime trade", "naval power" ],
      cluster_members_detail: "[1] United Kingdom (Europe)\n[2] Japan (Asia)\n[3] Singapore (Asia)"
    )

    assert chat.persisted?
    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "Find patterns in maritime gateway states"
    assert_includes system_message.content, "Maritime Trade and Naval Power"
    assert_includes system_message.content, "[1] United Kingdom (Europe)"
  end
end
