# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioPublishable.instance_variable_get(:@configuration)
    @original_capabilities = snapshot_capability_map
    @original_capability_options = snapshot_capability_options
    RecordingStudioPublishable.reset_configuration!
  end

  def teardown
    RecordingStudioPublishable.instance_variable_set(:@configuration, @original_configuration)
    restore_capability_state!
  end

  def snapshot_capability_map
    current = RecordingStudio.configuration.instance_variable_get(:@capabilities) || {}
    current.transform_values(&:dup)
  end

  def snapshot_capability_options
    (RecordingStudio.configuration.instance_variable_get(:@capability_options) || {}).dup
  end

  def restore_capability_state!
    RecordingStudio.configuration.instance_variable_set(:@capabilities, @original_capabilities)
    RecordingStudio.configuration.instance_variable_set(:@capability_options, @original_capability_options)
  end

  def test_register_public_path_persists_template_by_recordable_type
    RecordingStudioPublishable.configuration.register_public_path("Page", path: "/pages/:uuid/:slug")

    assert_equal "/pages/:uuid/:slug", RecordingStudioPublishable.configuration.public_path_for("Page")
    assert_equal "/published/:uuid/:slug", RecordingStudioPublishable.configuration.public_path_for("UnknownType")
  end

  def test_register_public_renderer_persists_controller_action_and_layout
    RecordingStudioPublishable.configuration.register_public_renderer(
      "Page",
      controller: "pages",
      action: :show,
      layout: "flat_pack_sidebar"
    )

    assert_equal "pages", RecordingStudioPublishable.configuration.public_controller_for("Page")
    assert_equal :show, RecordingStudioPublishable.configuration.public_action_for("Page")
    assert_equal "flat_pack_sidebar", RecordingStudioPublishable.configuration.public_layout_for("Page")
    assert_equal "pages/show", RecordingStudioPublishable.configuration.public_template_for("Page")
  end

  def test_register_public_renderer_persists_path_template_when_provided
    RecordingStudioPublishable.configuration.register_public_renderer(
      "Article",
      controller: "articles",
      action: :show,
      path: "/blogs/:uuid/:slug"
    )

    assert_equal "/blogs/:uuid/:slug", RecordingStudioPublishable.configuration.public_path_for("Article")
  end

  def test_parent_recordable_defaults_do_not_override_an_existing_custom_path
    RecordingStudioPublishable.configuration.register_public_path("PublishablePathProbe", path: "/blogs/:uuid/:slug")

    klass = Class.new do
      def self.name
        "PublishablePathProbe"
      end

      include RecordingStudio::Capabilities::Publishable.to
    end

    assert_equal "/blogs/:uuid/:slug", RecordingStudioPublishable.configuration.public_path_for("PublishablePathProbe")
    assert_equal "/blogs/:uuid/:slug", klass.recording_studio_publishable_path_template
  end

  def test_register_public_path_rejects_templates_without_uuid
    error = assert_raises(ArgumentError) do
      RecordingStudioPublishable.configuration.register_public_path("Article", path: "/blogs/:slug")
    end

    assert_includes error.message, ":uuid"
  end

  def test_layout_defaults_to_the_blank_engine_layout
    assert_equal "recording_studio_publishable/application", RecordingStudioPublishable.configuration.layout
  end

  def test_default_layout_alias_reads_from_layout
    RecordingStudioPublishable.configuration.layout = "application"

    assert_equal "application", RecordingStudioPublishable.configuration.default_layout
  end

  def test_default_layout_alias_writes_to_layout
    RecordingStudioPublishable.configuration.default_layout = "application"

    assert_equal "application", RecordingStudioPublishable.configuration.layout
  end

  def test_default_public_renderer_uses_recordable_type_convention
    assert_equal "pages", RecordingStudioPublishable.configuration.public_controller_for("Page")
    assert_equal :show, RecordingStudioPublishable.configuration.public_action_for("Page")
    assert_equal "pages/show", RecordingStudioPublishable.configuration.public_template_for("Page")
  end

  def test_schedule_and_seo_capabilities_default_to_true
    klass = Class.new do
      def self.name
        "PublishableCapabilityDefaults"
      end

      include RecordingStudio::Capabilities::Publishable.to
    end

    assert_equal true, klass.recording_studio_publishable_schedule_enabled
    assert_equal true, klass.recording_studio_publishable_seo_enabled
    assert_equal true, RecordingStudioPublishable.configuration.schedule_enabled_for(klass)
    assert_equal true, RecordingStudioPublishable.configuration.seo_enabled_for(klass)
  end

  def test_schedule_and_seo_capabilities_can_be_disabled_from_model_dsl
    klass = Class.new do
      def self.name
        "PublishableCapabilityOptOut"
      end

      include RecordingStudio::Capabilities::Publishable.to(schedule: false, seo: false)
    end

    assert_equal false, klass.recording_studio_publishable_schedule_enabled
    assert_equal false, klass.recording_studio_publishable_seo_enabled
    assert_equal false, RecordingStudioPublishable.configuration.schedule_enabled_for(klass)
    assert_equal false, RecordingStudioPublishable.configuration.seo_enabled_for(klass)
  end

  def test_merge_updates_known_attributes
    RecordingStudioPublishable.configuration.merge!(
      default_time_zone: "Pacific Time (US & Canada)",
      layout: "application",
      canonical_redirect_status: :moved_permanently
    )

    assert_equal "Pacific Time (US & Canada)", RecordingStudioPublishable.configuration.default_time_zone
    assert_equal "application", RecordingStudioPublishable.configuration.layout
    assert_equal :moved_permanently, RecordingStudioPublishable.configuration.canonical_redirect_status
  end

  def test_default_management_authorizer_denies_without_access_adapter
    result = RecordingStudioPublishable.configuration.authorize_management?(
      recording: Object.new,
      actor: Object.new,
      controller: nil
    )

    assert_equal false, result
  end

  def test_management_close_url_defaults_to_root_path
    main_app = Struct.new(:root_path).new("/dashboard")
    controller = Struct.new(:main_app).new(main_app)

    result = RecordingStudioPublishable.configuration.management_close_url_for(
      controller: controller,
      recording: nil
    )

    assert_equal "/dashboard", result
  end

  def test_management_close_url_can_be_overridden
    RecordingStudioPublishable.configuration.management_close_url_resolver = lambda do |controller:, recording:|
      "/workspace/#{recording.id}"
    end

    recording = Struct.new(:id).new(42)
    result = RecordingStudioPublishable.configuration.management_close_url_for(
      controller: Object.new,
      recording: recording
    )

    assert_equal "/workspace/42", result
  end
end
