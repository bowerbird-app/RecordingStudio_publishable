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
  SocialPublishable = Struct.new(:seo_title, :seo_description, :canonical_url, :social_title, :social_description, :slug,
                                 :social_image_attachment_recording) do
    def currently_published?
      true
    end

    def social_image_attached?
      social_image_attachment_recording.present?
    end
  end

  def test_publishable_head_tags_renders_title_description_and_canonical_fallbacks
    parent_recordable = Struct.new(:title).new("Launch Checklist")
    parent_recording = ParentRecording.new("Folder", parent_recordable)
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
    parent_recording = ParentRecording.new("Folder", parent_recordable)
    publishable = Publishable.new("SEO headline", "Search-friendly description", nil, nil, nil, "launch-checklist")
    publishable.define_singleton_method(:currently_published?) { false }
    publishable_recording = PublishableRecording.new("123", publishable, parent_recording)
    view = ViewContext.new(Struct.new(:base_url).new("https://example.test"))

    html = view.publishable_head_tags(publishable_recording: publishable_recording, publishable: publishable)

    assert_equal "", html.to_s
  end

  def test_publishable_head_tags_renders_social_image_dimensions_when_image_url_present
    parent_recordable = Struct.new(:title).new("Launch Checklist")
    parent_recording = ParentRecording.new("Folder", parent_recordable)
    publishable = Publishable.new("SEO headline", "Search-friendly description", nil, "Social headline", "Social description",
                                  "launch-checklist")
    publishable_recording = PublishableRecording.new("123", publishable, parent_recording)
    view = ViewContext.new(Struct.new(:base_url).new("https://example.test"))

    html = view.publishable_head_tags(
      publishable_recording: publishable_recording,
      publishable: publishable,
      social_image_url: "https://example.test/images/social-card.jpg"
    )

    assert_includes html, '<meta property="og:image" content="https://example.test/images/social-card.jpg">'
    assert_includes html, '<meta property="og:image:width" content="1200">'
    assert_includes html, '<meta property="og:image:height" content="630">'
    assert_includes html, '<meta name="twitter:card" content="summary_large_image">'
    assert_includes html, '<meta name="twitter:image" content="https://example.test/images/social-card.jpg">'
  end

  def test_publishable_head_tags_resolves_social_image_url_from_attachment_preview
    parent_recordable = Struct.new(:title).new("Launch Checklist")
    parent_recording = ParentRecording.new("Folder", parent_recordable)
    attachment_recording = Struct.new(:id).new("attachment-123")
    publishable = SocialPublishable.new("SEO headline", "Search-friendly description", nil, "Social headline",
                                        "Social description", "launch-checklist", attachment_recording)
    publishable_recording = PublishableRecording.new("123", publishable, parent_recording)
    view = ViewContext.new(Struct.new(:base_url).new("https://example.test"))

    routes = Object.new
    routes.define_singleton_method(:attachment_preview_file_path) do |_recording, variant_name:|
      "/attachments/social-card-#{variant_name}.jpg"
    end
    view.define_singleton_method(:recording_studio_attachable) { routes }

    html = view.publishable_head_tags(
      publishable_recording: publishable_recording,
      publishable: publishable
    )

    assert_includes html, '<meta property="og:image" content="https://example.test/attachments/social-card-social_share.jpg">'
    assert_includes html, '<meta property="og:image:width" content="1200">'
    assert_includes html, '<meta property="og:image:height" content="630">'
    assert_includes html, '<meta name="twitter:image" content="https://example.test/attachments/social-card-social_share.jpg">'
  end

  def test_publishable_head_tags_omits_seo_tags_when_seo_capability_is_disabled
    parent_recordable = Struct.new(:title).new("Launch Checklist")
    parent_recording = ParentRecording.new("Folder", parent_recordable)
    publishable = Publishable.new(
      "SEO headline",
      "Search-friendly description",
      "https://example.test/custom-canonical",
      "Social headline",
      "Social description",
      "launch-checklist"
    )
    publishable_recording = PublishableRecording.new("123", publishable, parent_recording)
    view = ViewContext.new(Struct.new(:base_url).new("https://example.test"))

    config = Object.new
    config.define_singleton_method(:seo_enabled_for) { |_recordable_type| false }

    html = RecordingStudioPublishable.stub(:configuration, config) do
      view.publishable_head_tags(
        publishable_recording: publishable_recording,
        publishable: publishable,
        parent_recordable: parent_recordable
      )
    end

    refute_includes html, "<title>"
    refute_includes html, '<meta name="description"'
    refute_includes html, '<link rel="canonical"'
    assert_includes html, '<meta property="og:title" content="Social headline">'
    assert_includes html, '<meta property="og:description" content="Social description">'
    assert_includes html, '<meta name="twitter:title" content="Social headline">'
  end
end
