# frozen_string_literal: true

require "test_helper"

class RecordableTypesServiceTest < Minitest::Test
  def setup
    @original_types = RecordingStudio.configuration.recordable_types
  end

  def teardown
    RecordingStudio.configuration.recordable_types = @original_types
  end

  def test_filtered_types_returns_only_configured_constantized_classes
    RecordingStudio.configuration.recordable_types = ["String", "", nil, "MissingConstant", "Object"]

    assert_equal %w[String Object], RecordingStudio::RecordableTypesService.filtered_types
  end

  def test_valid_recordable_type_accepts_class_based_configuration
    RecordingStudio.configuration.recordable_types = [String]

    assert RecordingStudio::RecordableTypesService.valid_recordable_type?("String")
  end

  def test_valid_recordable_type_rejects_values_not_present_in_configuration
    RecordingStudio.configuration.recordable_types = [Array]

    refute RecordingStudio::RecordableTypesService.valid_recordable_type?("String")
  end

  def test_valid_recordable_type_returns_false_when_input_raises
    invalid_type = Object.new
    invalid_type.define_singleton_method(:to_s) { raise "boom" }
    RecordingStudio.configuration.recordable_types = ["String"]

    refute RecordingStudio::RecordableTypesService.valid_recordable_type?(invalid_type)
  end
end
