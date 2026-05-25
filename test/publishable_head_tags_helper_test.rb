# frozen_string_literal: true

require "test_helper"
require "action_view"
require_relative "../app/helpers/recording_studio_publishable/application_helper"

class PublishableHeadTagsHelperTest < Minitest::Test
  ViewContext = Struct.new(:request) do
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::OutputSafetyHelper
    include RecordingStudioPublishable::ApplicationHelper
  end

  Publishable = Struct.new(:seo_title, :seo_description, :canonical_url, :social_title, :social_description, :slug) do
    def currently_published?
      true
    end
  end

  PublishableRecording = Struct.new(:id, :recordable, :parent_recording)
  ParentRecording = Struct.new(:recordable_type, :recordable)

  def test_publishable_head_tags_renders_title_description_and_canonical_fallbacks
    parent_recordable = Struct.new(:title).new("Launch Checklist")
    parent_recording = ParentRecording.new("Article", parent_recordable)
    publishable = Publishable.new(
      "SEO headline",
      "Search-friendly description",
      nil,
      "Social headline",
      "Social description",
      "launch-checklist"
    )
    publishable_recording = PublishableRecording.new("123", publishable, parent_recording)
    view = ViewContext.new(Struct.new(:base_url).new("https://example.test"))

    html = view.publishable_head_tags(
      publishable_recording: publishable_recording,
      publishable: publishable,
      parent_recordable: parent_recordable
    )

    assert_includes html, "<title>SEO headline</title>"
    assert_includes html, '<meta name="description" content="Search-friendly description">'
    assert_includes html, '<link rel="canonical" href="https://example.test/published/123/launch-checklist">'
    assert_includes html, '<meta property="og:title" content="Social headline">'
    assert_includes html, '<meta property="og:description" content="Social description">'
    assert_includes html, '<meta property="og:url" content="https://example.test/published/123/launch-checklist">'
    assert_includes html, '<meta name="twitter:card" content="summary">'
    assert_includes html, '<meta name="twitter:title" content="Social headline">'
    assert_includes html, '<meta name="twitter:description" content="Social description">'
  end

  def test_publishable_head_tags_returns_blank_for_unpublished_records
    parent_recordable = Struct.new(:title).new("Launch Checklist")
    parent_recording = ParentRecording.new("Article", parent_recordable)
    publishable = Publishable.new("SEO headline", "Search-friendly description", nil, nil, nil, "launch-checklist")
    publishable.define_singleton_method(:currently_published?) { false }
    publishable_recording = PublishableRecording.new("123", publishable, parent_recording)
    view = ViewContext.new(Struct.new(:base_url).new("https://example.test"))

    html = view.publishable_head_tags(publishable_recording: publishable_recording, publishable: publishable)

    assert_equal "", html.to_s
  end
end
