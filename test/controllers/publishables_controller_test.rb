# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "cgi"
require "nokogiri"
require "devise/test/integration_helpers"
require "rails/test_help"

class PublishablesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "PublishablesTestPassword!2026"

  setup do
    @original_close_url_resolver = RecordingStudioPublishable.configuration.management_close_url_resolver

    @user = User.find_or_create_by!(email: "publishables-test@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end

    sign_in @user
  end

  teardown do
    RecordingStudioPublishable.configuration.management_close_url_resolver = @original_close_url_resolver
  end

  test "publish transition shows the success page" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    patch recording_studio_publishable.transition_recording_publishable_path(recording_id: parent_recording.id,
                                                                             transition: "publish")

    assert_redirected_to recording_studio_publishable.publishable_success_path(recording_id: parent_recording.id)

    follow_redirect!

    assert_response :success
    assert_includes response.body, "Published!"
    assert_includes response.body, "Spring Release Notes"
    assert_includes response.body, "Copy link"
    assert_includes response.body, "View"
    assert_includes response.body, "/blogs/#{parent_recording.publishable_child_recording.id}/spring-release-notes"
  end

  test "preview shows the public template to an editor with noindex" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      actor: @user,
      attributes: { slug: "spring-release-notes", status: "draft" }
    ).value!

    get recording_studio_publishable.preview_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_includes response.body, "Spring Release Notes"
    assert_includes response.body, "Rendered through:"
    assert_includes response.body, '<meta name="robots" content="noindex,nofollow">'
    refute_includes response.body, '<link rel="canonical"'
    refute_includes response.body, 'name="twitter:title"'
    refute_includes response.body, 'property="og:type" content="article"'
    assert_includes response.body, "Preview"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "?preview="
  end

  test "preview of a scheduled page is not the public url" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      actor: @user,
      attributes: {
        slug: "spring-release-notes",
        status: "published",
        publish_at: 2.days.from_now,
        time_zone: "UTC"
      }
    ).value!

    get recording_studio_publishable.preview_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_includes response.body, "Spring Release Notes"
    assert_includes response.body, '<meta name="robots" content="noindex,nofollow">'
    refute parent_recording.reload.current_publishable.currently_published?
  end

  test "preview returns not found when logged out" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      actor: @user,
      attributes: { slug: "spring-release-notes", status: "draft" }
    ).value!
    sign_out @user

    get recording_studio_publishable.preview_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :not_found
  end

  test "preview shows the public template to a view-only person" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      actor: @user,
      attributes: { slug: "spring-release-notes", status: "draft" }
    ).value!
    viewer = User.find_or_create_by!(email: "publishables-viewer@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end
    RecordingStudioAccessible.grant_access(
      recording: parent_recording.root_recording,
      actor: viewer,
      role: :view,
      manager_actor: @user
    )
    sign_in viewer

    get recording_studio_publishable.preview_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_includes response.body, "Spring Release Notes"
    assert_includes response.body, '<meta name="robots" content="noindex,nofollow">'
    assert_includes response.body, "Preview"
  end

  test "preview does not create a publishable child" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Preview workspace"))
    parent_recording = RecordingStudio::Recording.create!(
      recordable: Article.create!(title: "No child yet"),
      parent_recording: root
    )
    grant_edit_access!(root)

    assert_nil parent_recording.publishable_child_recording

    get recording_studio_publishable.preview_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :not_found
    assert_nil parent_recording.reload.publishable_child_recording
  end

  test "published to draft does not show the success page" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")
    publish_parent_recording!(parent_recording)

    patch recording_studio_publishable.transition_recording_publishable_path(recording_id: parent_recording.id,
                                                                             transition: "draft")

    assert_redirected_to recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)

    follow_redirect!

    assert_response :success
    refute_includes response.body, "Published!"
  end

  test "published to scheduled does not show the success page" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")
    publish_parent_recording!(parent_recording)

    patch recording_studio_publishable.publishable_path(recording_id: parent_recording.id), params: {
      section: "schedule",
      publishable: {
        publish_at: 1.day.from_now.utc.strftime("%Y-%m-%dT%H:%M"),
        time_zone: "UTC"
      }
    }

    assert_redirected_to schedule_path_for(parent_recording)

    follow_redirect!

    assert_response :success
    refute_includes response.body, "Published!"
  end

  test "inline html publish stays on the referring page" do
    parent_recording = build_publishable_parent(title: "Inline Publish Page")

    patch recording_studio_publishable.transition_recording_publishable_path(
      recording_id: parent_recording.id,
      transition: "publish",
      inline: 1
    ), headers: { "HTTP_REFERER" => "http://www.example.com/" }

    assert_redirected_to "http://www.example.com/"
    follow_redirect!

    assert_response :success
    refute_includes response.body, "Published!"
    assert parent_recording.reload.current_publishable.currently_published?
  end

  test "inline html draft stays on the referring page" do
    parent_recording = build_publishable_parent(title: "Inline Draft Page")
    publish_parent_recording!(parent_recording)

    patch recording_studio_publishable.transition_recording_publishable_path(
      recording_id: parent_recording.id,
      transition: "draft",
      inline: 1
    ), headers: { "HTTP_REFERER" => "http://www.example.com/" }

    assert_redirected_to "http://www.example.com/"
    follow_redirect!

    assert_response :success
    refute_includes response.body, "Published!"
    assert parent_recording.reload.current_publishable.draft_state?
  end

  test "turbo stream publish replaces the dropdown and stays off the success page" do
    parent_recording = build_publishable_parent(title: "Stream Publish Page")

    patch recording_studio_publishable.transition_recording_publishable_path(
      recording_id: parent_recording.id,
      transition: "publish",
      inline: 1
    ), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, RecordingStudioPublishable::QuickActions::Component.wrapper_id(parent_recording)
    assert_includes CGI.unescapeHTML(response.body), "Published"
    assert_includes response.body, "Unpublish"
    assert_includes response.body, "button-padding-y-md"
    assert_includes response.body, "View"
    refute_includes CGI.unescapeHTML(response.body), "It's live."
    refute_includes response.body, "Published!"
    assert parent_recording.reload.current_publishable.currently_published?
  end

  test "turbo stream publish keeps a small host dropdown small" do
    parent_recording = build_publishable_parent(title: "Stream Size Page")

    patch recording_studio_publishable.transition_recording_publishable_path(
      recording_id: parent_recording.id,
      transition: "publish",
      inline: 1,
      button_size: "sm"
    ), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, "button-padding-y-sm"
    refute_includes response.body, "button-padding-y-md"
    assert parent_recording.reload.current_publishable.currently_published?
  end

  test "turbo stream draft replaces the dropdown with draft actions" do
    parent_recording = build_publishable_parent(title: "Stream Draft Page")
    publish_parent_recording!(parent_recording)

    patch recording_studio_publishable.transition_recording_publishable_path(
      recording_id: parent_recording.id,
      transition: "draft",
      inline: 1
    ), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "Draft"
    assert_includes response.body, "Publish now"
    assert_includes response.body, "Schedule"
    assert_includes response.body, "Preview"
    refute_includes response.body, "Back to a draft."
    refute_includes response.body, "Published!"
    assert parent_recording.reload.current_publishable.draft_state?
  end

  test "direct success page access redirects back to edit" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    get recording_studio_publishable.publishable_success_path(recording_id: parent_recording.id)

    assert_redirected_to recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)
  end

  test "edit and success pages use configured page nav close url" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")
    RecordingStudioPublishable.configuration.management_close_url_resolver = lambda do |recording:, **|
      "/workspace/#{recording.id}"
    end

    get recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)
    assert_response :success
    assert_includes response.body, "/workspace/#{parent_recording.id}"

    patch recording_studio_publishable.transition_recording_publishable_path(recording_id: parent_recording.id,
                                                                             transition: "publish")
    follow_redirect!

    assert_response :success
    assert_includes response.body, "/workspace/#{parent_recording.id}"
  end

  test "hub lists publish jobs and quick actions without job fields" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    get recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_equal %w[Preview Schedule SEO Social], hub_list_titles
    assert_includes response.body, "See it before it goes live."
    assert_includes response.body, preview_path_for(parent_recording)
    assert_includes response.body, "Schedule"
    assert_includes response.body, "SEO"
    assert_includes response.body, "Social"
    assert_includes response.body, "Pick when this goes live."
    assert_includes response.body, "How this shows up in search."
    assert_includes response.body, "How this looks when someone shares it."
    assert_includes response.body, RecordingStudioPublishable::QuickActions::Component.wrapper_id(parent_recording)
    assert_includes response.body, "Publish now"
    assert_includes response.body, schedule_path_for(parent_recording)
    assert_includes response.body, search_path_for(parent_recording)
    assert_includes response.body, social_path_for(parent_recording)
    refute_includes response.body, "datetime-local"
    refute_includes response.body, "Title in search"
    refute_includes response.body, "publishable[canonical_url]"
    refute_includes response.body, "publishable[social_title]"
  end

  test "published hub lists View first at the live url" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")
    publish_parent_recording!(parent_recording)

    get recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_equal %w[View Schedule SEO Social], hub_list_titles
    assert_includes response.body, "See it live."
    child = parent_recording.publishable_child_recording
    assert child
    assert_includes response.body, child.id.to_s
    refute_includes Nokogiri::HTML(response.body).at_css('[role=listitem] a')["href"], "preview"
  end

  test "scheduled hub lists Preview first" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      actor: @user,
      attributes: { slug: "spring-release-notes", status: "published", publish_at: 2.days.from_now }
    ).value!

    get recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_equal %w[Preview Schedule SEO Social], hub_list_titles
    assert_includes response.body, preview_path_for(parent_recording)
  end

  test "schedule page has times and not search or social fields" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    get recording_studio_publishable.schedule_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_includes response.body, "Pick when this goes live."
    assert_includes response.body, "flex w-full max-w-xl"
    refute_includes response.body, "mx-auto flex w-full max-w-xl"
    assert_includes response.body, 'type="datetime-local" name="publishable[publish_at]"'
    assert_includes response.body, 'type="datetime-local" name="publishable[unpublish_at]"'
    refute_includes response.body, "Title in search"
    refute_includes response.body, "data-publishable-social-image-picker"
    refute_includes response.body, "Select social image"
  end

  test "search page has listing fields and not times or social image" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    get recording_studio_publishable.search_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_includes response.body, "SEO"
    assert_includes response.body, "publishable[slug]"
    assert_includes response.body, "publishable[canonical_url]"
    assert_includes response.body, "publishable[meta_robots]"
    assert_includes response.body, "Canonical URL"
    assert_includes response.body, "Search listing"
    assert_includes response.body, "Title in search"
    assert_includes response.body, "Description in search"
    refute_includes response.body, "datetime-local"
    refute_includes response.body, "data-publishable-social-image-picker"
    refute_includes response.body, "Select social image"
    refute_includes response.body, 'name="publishable[meta_robots]" type="hidden"'
  end

  test "social page has preview fields and not times" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    get recording_studio_publishable.social_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_includes response.body, "Social title"
    assert_includes response.body, "How this looks when someone shares it."
    assert_includes response.body, "publishable[social_title]"
    assert_includes response.body, "data-publishable-social-image-picker"
    assert_includes response.body, "Select social image"
    refute_includes response.body, "datetime-local"
  end

  test "schedule save redirects to schedule and persists publish_at" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")
    publish_at = 2.days.from_now.utc.strftime("%Y-%m-%dT%H:%M")

    patch recording_studio_publishable.publishable_path(recording_id: parent_recording.id), params: {
      section: "schedule",
      publishable: {
        publish_at: publish_at,
        time_zone: "UTC"
      }
    }

    assert_redirected_to schedule_path_for(parent_recording)

    publishable = parent_recording.reload.current_publishable
    assert publishable.publish_at.present?
    assert_equal "published", publishable.status
    assert publishable.scheduled_for_future?

    follow_redirect!

    assert_response :success
    assert_includes response.body, "Times saved."
    refute_includes response.body, "Published!"
  end

  test "search save stays on search" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    patch recording_studio_publishable.publishable_path(recording_id: parent_recording.id), params: {
      section: "search",
      publishable: {
        slug: "spring-release-notes",
        canonical_url: "https://example.test/canonical",
        meta_robots: "noindex,follow"
      }
    }

    assert_redirected_to search_path_for(parent_recording)

    publishable = parent_recording.reload.current_publishable
    assert_equal "spring-release-notes", publishable.slug
    assert_equal "https://example.test/canonical", publishable.canonical_url
    assert_equal "noindex,follow", publishable.meta_robots

    follow_redirect!

    assert_response :success
    assert_includes response.body, "SEO saved."
    refute_includes response.body, "Published!"
  end

  test "search save ignores social fields" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    patch recording_studio_publishable.publishable_path(recording_id: parent_recording.id), params: {
      section: "search",
      publishable: {
        slug: "spring-release-notes",
        social_title: "should-not-save"
      }
    }

    assert_redirected_to search_path_for(parent_recording)
    assert_nil parent_recording.reload.current_publishable.social_title
  end

  test "social save stays on social" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    patch recording_studio_publishable.publishable_path(recording_id: parent_recording.id), params: {
      section: "social",
      publishable: {
        social_title: "Share this",
        social_description: "A line for the card."
      }
    }

    assert_redirected_to social_path_for(parent_recording)

    publishable = parent_recording.reload.current_publishable
    assert_equal "Share this", publishable.social_title
    assert_equal "A line for the card.", publishable.social_description

    follow_redirect!

    assert_response :success
    assert_includes response.body, "Social preview saved."
    refute_includes response.body, "Published!"
  end

  test "update without a section returns to the hub" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    patch recording_studio_publishable.publishable_path(recording_id: parent_recording.id), params: {
      publishable: { slug: "should-not-change" }
    }

    assert_redirected_to recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)
    refute_equal "should-not-change", parent_recording.reload.current_publishable&.slug
  end

  test "schedule page redirects to the hub when scheduling is off" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    RecordingStudioPublishable.configuration.stub :schedule_enabled_for, false do
      get recording_studio_publishable.schedule_recording_publishable_path(recording_id: parent_recording.id)

      assert_redirected_to edit_path_for(parent_recording)
    end
  end

  test "hub omits schedule when scheduling is off" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    RecordingStudioPublishable.configuration.stub :schedule_enabled_for, false do
      get recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)

      assert_response :success
      refute_includes response.body, schedule_path_for(parent_recording)
      assert_includes response.body, search_path_for(parent_recording)
      assert_includes response.body, social_path_for(parent_recording)
    end
  end

  private

  def edit_path_for(parent_recording)
    recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)
  end

  def schedule_path_for(parent_recording)
    recording_studio_publishable.schedule_recording_publishable_path(recording_id: parent_recording.id)
  end

  def search_path_for(parent_recording)
    recording_studio_publishable.search_recording_publishable_path(recording_id: parent_recording.id)
  end

  def social_path_for(parent_recording)
    recording_studio_publishable.social_recording_publishable_path(recording_id: parent_recording.id)
  end

  def preview_path_for(parent_recording)
    recording_studio_publishable.preview_recording_publishable_path(recording_id: parent_recording.id)
  end

  def hub_list_titles
    Nokogiri::HTML(response.body).css("[role=listitem] p.font-medium").map { |node| node.text.strip }
  end

  def build_publishable_parent(title:)
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Publishable workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Article.create!(title: title),
                                                          parent_recording: root)
    grant_edit_access!(root)
    parent_recording
  end

  def publish_parent_recording!(parent_recording)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      actor: @user,
      attributes: { slug: "spring-release-notes", status: "published" }
    ).value!
  end

  def grant_edit_access!(root_recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: root_recording,
      actor: @user
    )
    result.respond_to?(:value!) ? result.value! : result
  end
end
