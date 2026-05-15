# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "devise/test/integration_helpers"
require "rails/test_help"

class DocsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "DocsTestPassword!2026"

  setup do
    @user = User.find_or_create_by!(email: "docs-test@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end

    sign_in @user
  end

  test "recordable types include publishable" do
    get docs_recordable_types_path

    assert_response :success
    assert_includes response.body, "Publishable"
  end

  test "install page uses the title subtitle content layout" do
    get docs_install_path

    assert_response :success
    assert_includes response.body, "Install"
    assert_includes response.body, "Set up the host app, migrations, seeds, and optional Active Storage support"
    assert_includes response.body, "What the generator does"
    refute_includes response.body, "FlatPack::Card"
  end

  test "config page uses the title subtitle content layout" do
    get docs_config_path

    assert_response :success
    assert_includes response.body, "Config"
    assert_includes response.body,
                    "Tune the host-app actor lookup, layouts, public renderer overrides, and redirect behavior."
    assert_includes response.body, "Available settings"
    refute_includes response.body, "FlatPack::Card"
  end

  test "recordings tree renders seeded publishable nodes" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Docs Workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Docs Page"),
                                                          parent_recording: root)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "docs-page", status: "published" }
    )

    get docs_recordings_tree_path

    assert_response :success
    assert_includes response.body, "Publishable: docs-page"
    assert_includes response.body, "Page: Docs Page"
  end

  test "gem views page points at renamed engine views" do
    get docs_gem_views_path

    assert_response :success
    assert_includes response.body, "app/views/recording_studio_publishable/publishables/edit.html.erb"
  end

  test "methods page lists addon method families" do
    get docs_methods_path

    assert_response :success
    assert_includes response.body, "RecordingStudioPublishable::ParentRecordable"
    assert_includes response.body, "RecordingStudioPublishable::Publishable"
    assert_includes response.body, "Returns Page records."
    assert_includes response.body, "Page.currently_live"
    assert_includes response.body, "Returns RecordingStudioPublishable::Publishable records."
    assert_includes response.body, "RecordingStudioPublishable::Services::Publishables::Update"
    assert_includes response.body, "recording.publishable_public_url(host: &quot;example.test&quot;)"
    assert_includes response.body, "RecordingStudioPublishable::Routing.url_for"
    assert_includes response.body, "RecordingStudioPublishable.configuration.register_public_renderer"
  end

  test "helpers page lists addon view helpers" do
    get docs_helpers_path

    assert_response :success
    assert_includes response.body, "render_publishable_status_badge"
    assert_includes response.body, "render_publishable_quick_actions"
  end

  test "components page lists addon partial entry points" do
    get docs_components_path

    assert_response :success
    assert_includes response.body, "Components"
    assert_includes response.body, "app/components/recording_studio_publishable/status_badge/component.rb"
    assert_includes response.body, "app/components/recording_studio_publishable/quick_actions/component.rb"
    assert_includes response.body, "RecordingStudioPublishable::StatusBadge::Component.new(publishable: @publishable)"
    assert_includes response.body, "Required initializer arguments for this component"
    assert_includes response.body, "RecordingStudioPublishable::Publishable"
    assert_includes response.body, "RecordingStudio::Recording"
    assert_includes response.body, "Live rendering from the dummy app seed data"
  end
end
