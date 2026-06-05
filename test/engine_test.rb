# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioPublishable.instance_variable_get(:@configuration)
    RecordingStudioPublishable.reset_configuration!
  end

  def teardown
    RecordingStudioPublishable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_load_config_merges_yaml_and_x_config
    xcfg = Struct.new(:recording_studio_publishable).new({ default_time_zone: "UTC" })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { canonical_redirect_status: :moved_permanently }
      end
    end.new(app_config)

    initializer = RecordingStudioPublishable::Engine.initializers.find do |candidate|
      candidate.name == "recording_studio_publishable.load_config"
    end
    initializer.block.call(app)

    assert_equal "UTC", RecordingStudioPublishable.configuration.default_time_zone
    assert_equal :moved_permanently, RecordingStudioPublishable.configuration.canonical_redirect_status
  end

  def test_engine_is_isolated_under_recording_studio_publishable_namespace
    source = File.read(File.expand_path("../lib/recording_studio_publishable/engine.rb", __dir__))

    assert_includes source, "isolate_namespace RecordingStudioPublishable"
    assert_includes source, "register_publishable_recordable_type"
  end
end
