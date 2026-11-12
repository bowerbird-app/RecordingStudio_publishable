# frozen_string_literal: true

require "test_helper"

class PublishableShareButtonPageTest < ActionDispatch::IntegrationTest
  test "published page shows a share button that copies the public url" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Share page workspace"))
    recording = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: "Share page"),
      parent_recording: root
    )
    child = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "share-page", status: "published" }
    ).value!

    get "/published/#{child.id}/share-page"

    assert_response :success
    copied = response.body[/data-flat-pack--clipboard-text-value="([^"]*)"/, 1]
    path = recording.reload.recordable.published_url
    expected = path.to_s.match?(%r{\Ahttps?://}i) ? path : "#{request.base_url}#{path}"

    assert_equal expected, copied
    assert_includes response.body, 'aria-label="Share"'
    assert_includes response.body, "Copy link"
    assert_includes response.body, "arrow-up-tray"
    refute_includes copied.to_s, "/embeds/"
  end
end
