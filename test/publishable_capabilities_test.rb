# frozen_string_literal: true

require "test_helper"

class PublishableCapabilitiesTest < Minitest::Test
  def setup
    @original_capabilities = snapshot_capability_map
    @original_capability_options = snapshot_capability_options
  end

  def teardown
    RecordingStudio.configuration.instance_variable_set(:@capabilities, @original_capabilities)
    RecordingStudio.configuration.instance_variable_set(:@capability_options, @original_capability_options)
  end

  def snapshot_capability_map
    current = RecordingStudio.configuration.instance_variable_get(:@capabilities) || {}
    current.transform_values(&:dup)
  end

  def snapshot_capability_options
    (RecordingStudio.configuration.instance_variable_get(:@capability_options) || {}).dup
  end

  def test_to_wraps_include_for_and_does_not_invent_a_third_dsl
    source = File.read(File.expand_path("../lib/recording_studio/capabilities/publishable.rb", __dir__))

    assert_includes source, "RecordingStudio::Capabilities.include_for(:publishable"
    refute_includes source, "def self.enabled"
    refute_includes source, "recording_studio_publishable("
    refute_includes source, "enable_capability"
  end

  def test_to_delegates_to_include_for
    captured_name = nil
    captured_options = nil
    captured_block = nil
    returned = Module.new

    RecordingStudio::Capabilities.stub(:include_for, lambda { |name, **options, &block|
      captured_name = name
      captured_options = options
      captured_block = block
      returned
    }) do
      result = RecordingStudio::Capabilities::Publishable.to(schedule: false, seo: true)

      assert_same returned, result
    end

    assert_equal :publishable, captured_name
    assert_equal({ schedule: false, seo: true }, captured_options)
    assert_instance_of Proc, captured_block
  end

  def test_to_returns_a_concern_that_enables_on_include
    klass = Class.new do
      def self.name
        "PublishableEnablementProbe"
      end
    end

    klass.include(RecordingStudio::Capabilities::Publishable.to(schedule: false, seo: true))

    assert RecordingStudio.capability_enabled?(:publishable, for: klass)
    assert_equal({ schedule: false, seo: true }, RecordingStudio.capability_options(:publishable, for: klass))
    assert_includes klass.ancestors, RecordingStudioPublishable::ParentRecordable
  end

  def test_capability_registration_owns_the_publishable_child
    registration = RecordingStudio.registered_capabilities.fetch(:publishable)

    assert_equal "recording_studio_publishable", registration.fetch(:source)
    assert_includes registration.fetch(:child_recordables), "RecordingStudioPublishable::Publishable"
    assert_equal RecordingStudio::Capabilities::Publishable::RecordingMethods, registration.fetch(:recording_methods)
  end

  def test_installing_the_gem_does_not_enable_publishable
    refute RecordingStudio.capability_enabled?(:publishable, for: "Folder")
    refute RecordingStudio.capability_enabled?(:publishable, for: "UnenabledRecordable")
  end

  def test_gemspec_depends_on_recording_studio_and_not_trashable
    gemspec = File.read(File.expand_path("../recording_studio_publishable.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    refute_includes gemspec, "recording_studio_trashable"
  end
end
