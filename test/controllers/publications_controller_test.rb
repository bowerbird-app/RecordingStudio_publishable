ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"
require "rails/test_help"

class PublicationsControllerTest < ActionDispatch::IntegrationTest
  test "published content is reachable without signing in" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Public page"), parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "public-page", status: "published" }
    ).value

    get "/published/#{publishable_recording.id}/public-page"

    assert_response :success
    assert_includes response.body, "Public page"
  end

  test "stale slugs redirect to the canonical path" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Public page"), parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "public-page", status: "published" }
    ).value

    get "/published/#{publishable_recording.id}/old-slug"

    assert_response :redirect
    assert_equal "/published/#{publishable_recording.id}/public-page", response.location.sub(%r{^https?://[^/]+}, "")
  end
end
