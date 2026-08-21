# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

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
      publishable: {
        slug: "spring-release-notes",
        status: "published",
        publish_at: 1.day.from_now.utc.strftime("%Y-%m-%dT%H:%M"),
        time_zone: "UTC"
      }
    }

    assert_redirected_to recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)

    follow_redirect!

    assert_response :success
    refute_includes response.body, "Published!"
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

  test "edit form exposes canonical url and search listing" do
    parent_recording = build_publishable_parent(title: "Spring Release Notes")

    get recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_includes response.body, "publishable[canonical_url]"
    assert_includes response.body, "publishable[meta_robots]"
    assert_includes response.body, "Canonical URL"
    assert_includes response.body, "Search listing"
    refute_includes response.body, 'name="publishable[meta_robots]" type="hidden"'
  end

  private

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
