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
    assert_includes response.body,
                    "Run the installation commands for the publishable addon and optional companion gems."
    assert_includes response.body, "Add the gem"
    assert_includes response.body, "bundle add recording_studio_publishable"
    assert_includes response.body, "bin/rails generate recording_studio_publishable:install"
    assert_includes response.body, "Optional access control"
    refute_includes response.body, "Configure your models"
    refute_includes response.body, "Mounted routes"
    refute_includes response.body, "recording_studio_publishable("
    refute_includes response.body, "FlatPack::Card"
  end

  test "config page uses the title subtitle content layout" do
    get docs_config_path

    assert_response :success
    assert_includes response.body, "Config"
    assert_includes response.body,
                    "Configure global RecordingStudioPublishable behavior in the initializer."
    assert_includes response.body, "Available settings"
    assert_includes response.body, "RecordingStudioPublishable::Configuration"
    assert_includes response.body, "management_authorizer"
    refute_includes response.body, "Model-level setup (recommended)"
    refute_includes response.body, "recording_studio_publishable("
    refute_includes response.body, "Public head helper"
    refute_includes response.body, "FlatPack::Card"
  end

  test "setup page includes model and host wiring guidance" do
    get docs_setup_path

    assert_response :success
    assert_includes response.body, "Setup"
    assert_includes response.body, "Model setup"
    assert_includes response.body, "recording_studio_publishable("
    assert_includes response.body, "mount RecordingStudioPublishable::Engine, at: \&quot;/\&quot;"
    assert_includes response.body, "publishable_head_tags"
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
    assert_includes response.body, "Review the public methods, scopes, and helper entry points exposed by the addon."
    refute_includes response.body, "RecordingStudioPublishable::Configuration"
    assert_includes response.body, "RecordingStudioPublishable::ParentRecordable"
    refute_includes response.body,
             "Scopes you call on parent models (like Page/Article) that filter by publishable state and still return parent model records, not child Publishable rows."
    refute_includes response.body, "RecordingStudioPublishable::Publishable"
    assert_includes response.body, "schedule: false"
    assert_includes response.body, "seo: false"
    assert_includes response.body, "RecordingStudioPublishable.configuration.schedule_enabled_for(&quot;Page&quot;)"
    assert_includes response.body, "Returns Page records whose publishable child is live right now."
    assert_includes response.body, "RecordingStudio::Recording.find(recording_id).published?"
    assert_includes response.body, "RecordingStudio::Recording.scheduled_between(Time.current..2.weeks.from_now)"
    assert_includes response.body, "RecordingStudioPublishable::Routing.url_for"
    refute_includes response.body, "Build the canonical public path or full URL for a publishable child recording using one API."
    refute_includes response.body, "RecordingStudioPublishable::Services::BaseService"
  end

  test "components page lists addon partial entry points" do
    get docs_components_path

    assert_response :success
    assert_includes response.body, "Components"
    assert_includes response.body, "app/components/recording_studio_publishable/status_badge/component.rb"
    assert_includes response.body, "app/components/recording_studio_publishable/quick_actions/component.rb"
    assert_includes response.body,
                    "RecordingStudioPublishable::StatusBadge::Component.new(publishable: RecordingStudioPublishable::Publishable.new(status: :draft"
    assert_includes response.body, "slug: &quot;scheduled-demo&quot;, publish_at: 1.day.from_now"
    assert_includes response.body, "Initializer arguments for this component"
    assert_includes response.body, "RecordingStudioPublishable::Publishable"
    assert_includes response.body, "RecordingStudio::Recording"
    assert_includes response.body, "All possible status badge states"
  end

  test "headers page renders platform-style social previews for draft publishables" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Headers Docs Workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Headers Draft Page"),
                                                          parent_recording: root)

    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "headers-draft-page", status: "draft" }
    )

    get docs_headers_path(recording_id: parent_recording.id)

    assert_response :success
    assert_includes response.body, "Publishability"
    assert_includes response.body, "X (Twitter)-style preview"
    assert_includes response.body, "Facebook-style preview"
    assert_includes response.body, "publishable_status"
    assert_includes response.body, "currently_published"
  end

  test "headers resolved values show seo disabled and only social tags for page" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Headers SEO False Workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Headers SEO False Page"),
                                                          parent_recording: root)

    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: {
        slug: "headers-seo-false-page",
        status: "published",
        seo_title: "SEO title should be ignored",
        seo_description: "SEO description should be ignored"
      }
    )

    get docs_headers_path(recording_id: parent_recording.id)

    assert_response :success
    assert_includes response.body, "seo_enabled"
    assert_includes response.body, "false"
    assert_includes response.body, "meta[property=og:title]"
    assert_includes response.body, "meta[name=twitter:title]"
    refute_includes response.body, "meta[name=description]"
    refute_includes response.body, "link[rel=canonical]"
  end

  test "headers resolved values show seo tags when enabled for article" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Headers SEO True Workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Article.create!(title: "Headers SEO True Article"),
                                                          parent_recording: root)

    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: {
        slug: "headers-seo-true-article",
        status: "published",
        seo_title: "Headers SEO Title",
        seo_description: "Headers SEO Description"
      }
    )

    get docs_headers_path(recording_id: parent_recording.id)

    assert_response :success
    assert_includes response.body, "seo_enabled"
    assert_includes response.body, "true"
    assert_includes response.body, "title"
    assert_includes response.body, "Headers SEO Title"
    assert_includes response.body, "meta[name=description]"
    assert_includes response.body, "Headers SEO Description"
    assert_includes response.body, "link[rel=canonical]"
  end
end
