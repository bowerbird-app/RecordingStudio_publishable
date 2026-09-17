# frozen_string_literal: true

require "test_helper"

class PageLinkTest < Minitest::Test
  FakePublishable = Struct.new(:published, :scheduled) do
    def published_state? = published
    def scheduled_for_future? = scheduled
  end
  FakeChild = Struct.new(:id, :recordable)
  FakeSlug = Struct.new(:slug)
  FakeRecording = Struct.new(:current_publishable, :recordable_type, :publishable_child_recording)

  def test_draft_uses_preview
    recording = FakeRecording.new(FakePublishable.new(false, false), "Page", nil)
    link = RecordingStudioPublishable::PageLink.for(recording: recording, preview_href: "/preview")

    assert_equal "Preview", link.text
    assert_equal "See it before it goes live.", link.subtitle
    assert_equal "eye", link.icon
    assert_equal "/preview", link.href
  end

  def test_scheduled_uses_preview
    recording = FakeRecording.new(FakePublishable.new(true, true), "Page", child)
    link = RecordingStudioPublishable::PageLink.for(recording: recording, preview_href: "/preview")

    assert_equal "Preview", link.text
    assert_equal "/preview", link.href
  end

  def test_published_uses_view_at_the_public_path
    recording = FakeRecording.new(FakePublishable.new(true, false), "Page", child)
    link = RecordingStudioPublishable::PageLink.for(recording: recording, preview_href: "/preview")

    assert_equal "View", link.text
    assert_equal "See it live.", link.subtitle
    assert_equal "arrow-top-right-on-square", link.icon
    assert_equal "/published/child-id/hello", link.href
    refute_includes link.href, "preview"
  end

  def test_published_without_a_child_falls_back_to_preview
    recording = FakeRecording.new(FakePublishable.new(true, false), "Page", nil)
    link = RecordingStudioPublishable::PageLink.for(recording: recording, preview_href: "/preview")

    assert_equal "Preview", link.text
    assert_equal "/preview", link.href
  end

  private

  def child
    FakeChild.new("child-id", FakeSlug.new("hello"))
  end
end
