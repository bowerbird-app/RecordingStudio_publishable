# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioPublishable.instance_variable_get(:@configuration)
    RecordingStudioPublishable.reset_configuration!
  end

  def teardown
    RecordingStudioPublishable.instance_variable_set(:@configuration, @original_configuration)
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

  def test_edit_layout_defaults_to_the_active_default_layout
    assert_nil RecordingStudioPublishable.configuration.edit_layout
  end

  def test_default_public_renderer_uses_recordable_type_convention
    assert_equal "pages", RecordingStudioPublishable.configuration.public_controller_for("Page")
    assert_equal :show, RecordingStudioPublishable.configuration.public_action_for("Page")
    assert_equal "pages/show", RecordingStudioPublishable.configuration.public_template_for("Page")
  end

  def test_merge_updates_known_attributes
    RecordingStudioPublishable.configuration.merge!(
      default_time_zone: "Pacific Time (US & Canada)",
      canonical_redirect_status: :moved_permanently
    )

    assert_equal "Pacific Time (US & Canada)", RecordingStudioPublishable.configuration.default_time_zone
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
end
