# frozen_string_literal: true

require "test_helper"

class PublishableApiTest < Minitest::Test
  def test_registration_is_nil_when_recording_studio_api_is_undefined
    skip "RecordingStudioApi is loaded in this process" if defined?(RecordingStudioApi)

    assert_nil RecordingStudioPublishable::Api.register_capability_action!
  end

  def test_invalid_input_raises_standard_error_without_the_api_error_class
    skip "RecordingStudioApi is loaded in this process" if defined?(RecordingStudioApi)

    error = assert_raises(StandardError) do
      RecordingStudioPublishable::Api.invalid_input!("Social image is invalid", details: ["Social image is invalid"])
    end

    assert_instance_of StandardError, error
    assert_equal "Social image is invalid", error.message
  end

  def test_engine_registers_api_actions_before_the_api_initializer
    initializer = RecordingStudioPublishable::Engine.initializers.find do |candidate|
      candidate.name == "recording_studio_publishable.register_recording_studio_api_action"
    end

    assert_equal "recording_studio_api.after_initialize", initializer.before
  end
end
