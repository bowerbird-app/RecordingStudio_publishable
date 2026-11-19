# frozen_string_literal: true

require "test_helper"
require "action_view"
require "cgi"
require_relative "../app/helpers/recording_studio_publishable/application_helper"

class PublishableHeadTagsHelperTest < Minitest::Test
  ViewContext = Struct.new(:request) do
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::OutputSafetyHelper
    include RecordingStudioPublishable::ApplicationHelper
  end

  Publishable = Struct.new(:seo_title, :seo_description, :canonical_url, :social_title, :social_description, :slug,
                           :meta_robots) do
    def currently_published?
      true
    end

    def robots_value
      meta_robots.to_s.strip.presence || "index,follow"
    end
  end

  PublishableRecording = Struct.new(:id, :recordable, :parent_recording)
  ParentRecording = Struct.new(:recordable_type, :recordable)
  SocialPublishable = Struct.new(:seo_title, :seo_description, :canonical_url, :social_title, :social_description, :slug,
                                 :social_image_attachment_recording, :meta_robots) do
    def currently_published?
      true
    end

    def robots_value
      meta_robots.to_s.strip.presence || "index,follow"
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

    refute_includes html, "<title>"
    assert_equal "SEO headline", view.publishable_document_title(
      publishable_recording: publishable_recording,
      publishable: publishable,
      parent_recordable: parent_recordable
    )
    assert_includes html, '<meta name="description" content="Search-friendly description">'
    assert_includes html, '<link rel="canonical" href="https://example.test/published/123/launch-checklist">'
    assert_includes html, '<meta name="robots" content="index,follow">'
    assert_includes html, '<meta property="og:title" content="Social headline">'
    assert_includes html, '<meta property="og:description" content="Social description">'
    assert_includes html, '<meta property="og:url" content="https://example.test/published/123/launch-checklist">'
    assert_includes html, '<meta name="twitter:card" content="summary">'
    assert_includes html, '<meta name="twitter:title" content="Social headline">'
    assert_includes html, '<meta name="twitter:description" content="Social description">'
  end

  def test_publishable_head_tags_does_not_accept_title
    parent_recordable = Struct.new(:title).new("Launch Checklist")
    parent_recording = ParentRecording.new("Folder", parent_recordable)
    publishable = Publishable.new("SEO headline", "Search-friendly description", nil, nil, nil, "launch-checklist")
    publishable_recording = PublishableRecording.new("123", publishable, parent_recording)
    view = ViewContext.new(Struct.new(:base_url).new("https://example.test"))

    error = assert_raises(ArgumentError) do
      view.publishable_head_tags(
        publishable_recording: publishable_recording,
        publishable: publishable,
        title: "ignored"
      )
    end

    assert_match(/unknown keyword: :title/, error.message)
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
    assert_includes html, '<meta name="robots" content="index,follow">'
    assert_includes html, '<meta property="og:title" content="Social headline">'
    assert_includes html, '<meta property="og:description" content="Social description">'
    assert_includes html, '<meta name="twitter:title" content="Social headline">'
  end

  def test_publishable_head_tags_uses_canonical_override_and_emits_noindex_robots
    parent_recordable = Struct.new(:title).new("Launch Checklist")
    parent_recording = ParentRecording.new("Article", parent_recordable)
    publishable = Publishable.new(
      "SEO headline",
      "Search-friendly description",
      "https://example.test/original",
      "Social headline",
      "Social description",
      "launch-checklist",
      "noindex,follow"
    )
    publishable_recording = PublishableRecording.new("123", publishable, parent_recording)
    view = ViewContext.new(Struct.new(:base_url).new("https://example.test"))

    html = view.publishable_head_tags(
      publishable_recording: publishable_recording,
      publishable: publishable,
      parent_recordable: parent_recordable
    )

    refute_includes html, "<title>"
    assert_includes html, '<link rel="canonical" href="https://example.test/original">'
    assert_includes html, '<meta name="robots" content="noindex,follow">'
    refute_includes html, '<link rel="canonical" href="https://example.test/published/123/launch-checklist">'
  end

  def test_publishable_head_tags_emits_only_noindex_in_preview
    parent_recordable = Struct.new(:title).new("Launch Checklist")
    parent_recording = ParentRecording.new("Folder", parent_recordable)
    publishable = Publishable.new("SEO headline", "Search-friendly description", nil, "Social headline",
                                  "Social description", "launch-checklist")
    publishable.define_singleton_method(:currently_published?) { false }
    publishable_recording = PublishableRecording.new("123", publishable, parent_recording)
    view = ViewContext.new(Struct.new(:base_url).new("https://example.test"))
    view.define_singleton_method(:publishable_preview?) { true }

    html = view.publishable_head_tags(
      publishable_recording: publishable_recording,
      publishable: publishable,
      parent_recordable: parent_recordable
    )

    assert_equal '<meta name="robots" content="noindex,nofollow">', html
    refute_includes html, 'property="og:title"'
    refute_includes html, '<link rel="canonical"'
    assert_equal "SEO headline", view.publishable_document_title(
      publishable_recording: publishable_recording,
      publishable: publishable,
      parent_recordable: parent_recordable
    )
  end

  def test_meta_description_prefers_the_argument_then_seo_then_the_recordable
    recordable, calls = recordable_describing("From the article")
    publishable = live_publishable(seo_description: "Saved search line", social_description: "Saved card line")

    html, recording = render_head(publishable: publishable, recordable: recordable, description: "Argument line")

    assert_equal "Argument line", tag_content(html, "description")
    assert_equal "Saved card line", property_content(html, "og:description")
    assert_equal "Saved card line", RecordingStudioPublishable::SharePreview.for(recording).description
    assert_equal 0, calls.call

    html, recording = render_head(publishable: publishable, recordable: recordable)

    assert_equal "Saved search line", tag_content(html, "description")
    assert_equal "Saved card line", property_content(html, "og:description")
    assert_equal "Saved card line", RecordingStudioPublishable::SharePreview.for(recording).description
    assert_equal 0, calls.call
  end

  def test_meta_description_uses_the_recordable_when_seo_description_is_blank
    recordable, calls = recordable_describing("From the article")
    publishable = live_publishable(seo_description: "  ", social_description: nil)

    html, recording = render_head(publishable: publishable, recordable: recordable)

    assert_equal "From the article", tag_content(html, "description")
    assert_equal "From the article", property_content(html, "og:description")
    assert_equal "From the article", tag_content(html, "twitter:description")
    assert_equal "From the article", RecordingStudioPublishable::SharePreview.for(recording).description
    assert_operator calls.call, :>=, 1
  end

  def test_social_description_prefers_the_argument_then_social_then_seo_then_the_recordable
    recordable, = recordable_describing("From the article")
    publishable = live_publishable(seo_description: "Saved search line", social_description: "Saved card line")

    html, recording = render_head(
      publishable: publishable,
      recordable: recordable,
      social_description: "Argument card"
    )

    assert_equal "Argument card", property_content(html, "og:description")
    assert_equal "Argument card", tag_content(html, "twitter:description")
    assert_equal "Saved card line", RecordingStudioPublishable::SharePreview.for(recording).description

    html, recording = render_head(publishable: publishable, recordable: recordable)

    assert_social_description html, recording, "Saved card line"

    publishable = live_publishable(seo_description: "Saved search line", social_description: "")
    html, recording = render_head(publishable: publishable, recordable: recordable)

    assert_equal "Saved search line", tag_content(html, "description")
    assert_social_description html, recording, "Saved search line"

    publishable = live_publishable(seo_description: nil, social_description: nil)
    html, recording = render_head(publishable: publishable, recordable: recordable)

    assert_equal "From the article", tag_content(html, "description")
    assert_social_description html, recording, "From the article"
  end

  def test_meta_description_stays_off_when_seo_is_disabled_and_social_still_falls_through
    recordable, = recordable_describing("From the article")
    publishable = live_publishable(seo_description: "Saved search line", social_description: nil)
    disabled = Object.new
    disabled.define_singleton_method(:seo_enabled_for) { |_recordable_type| false }

    html, recording = RecordingStudioPublishable.stub(:configuration, disabled) do
      render_head(publishable: publishable, recordable: recordable, description: "Argument line")
    end

    refute_includes html, 'name="description"'
    assert_social_description html, recording, "Saved search line"
    refute_includes html, "From the article"
    refute_includes html, "Argument line"
  end

  def test_publishable_description_strips_html_and_squishes_whitespace
    recordable, = recordable_describing("<p>Hello <strong>there</strong></p>\n\n<script>nope</script>")
    publishable = live_publishable

    html, recording = render_head(publishable: publishable, recordable: recordable)

    assert_equal "Hello there", tag_content(html, "description")
    refute_includes tag_content(html, "description"), "nope"
    assert_social_description html, recording, "Hello there"
  end

  def test_publishable_description_truncates_on_a_word_boundary
    plain = (["alpha"] * 40).join(" ")
    recordable, = recordable_describing("<p>#{plain}</p>")
    publishable = live_publishable

    html, = render_head(publishable: publishable, recordable: recordable)
    text = tag_content(html, "description")

    assert_operator text.length, :<=, 160
    assert_operator text.length, :>=, 160 - "alpha".length
    assert plain.start_with?(text)
    assert_equal " ", plain[text.length]
    assert text.end_with?("alpha")
    refute_includes text, "<p>"
  end

  def test_publishable_description_cuts_a_long_word_at_160_characters
    recordable, = recordable_describing("b" * 180)
    publishable = live_publishable

    html, = render_head(publishable: publishable, recordable: recordable)

    assert_equal "b" * 160, tag_content(html, "description")
  end

  def test_a_short_publishable_description_is_kept_whole
    recordable, = recordable_describing("  A short line.  ")
    publishable = live_publishable

    html, = render_head(publishable: publishable, recordable: recordable)

    assert_equal "A short line.", tag_content(html, "description")
  end

  def test_blank_publishable_description_emits_no_description
    ["", "   ", nil, "<p> </p>", "<br>"].each do |blank|
      recordable, = recordable_describing(blank)
      publishable = live_publishable
      html, recording = render_head(publishable: publishable, recordable: recordable)

      refute_includes html.to_s, 'name="description"', blank.inspect
      refute_includes html.to_s, "og:description", blank.inspect
      refute_includes html.to_s, "twitter:description", blank.inspect
      assert_equal "", RecordingStudioPublishable::SharePreview.for(recording).description
    end
  end

  def test_raising_publishable_description_emits_no_description
    recordable, calls = recordable_describing(-> { raise "body that must stay private" })
    publishable = live_publishable

    html, recording = render_head(publishable: publishable, recordable: recordable)

    assert_operator calls.call, :>=, 1
    refute_includes html.to_s, "body that must stay private"
    refute_includes html.to_s, 'name="description"'
    refute_includes html.to_s, "og:description"
    assert_equal "", RecordingStudioPublishable::SharePreview.for(recording).description
  end

  def test_head_tags_do_not_read_publishable_description_for_draft_scheduled_or_unpublished
    %w[draft scheduled unpublished].each do |status|
      recordable, calls = recordable_describing("SECRET #{status}")
      publishable = live_publishable(seo_description: "Saved search line", social_description: "Saved card line")
      publishable.define_singleton_method(:currently_published?) { false }
      publishable.define_singleton_method(:status) { status }

      html, = render_head(publishable: publishable, recordable: recordable)

      assert_equal "", html.to_s, status
      assert_equal 0, calls.call, status
      refute_includes html.to_s, "SECRET #{status}"
    end
  end

  def test_preview_emits_only_robots_and_does_not_read_publishable_description
    recordable, calls = recordable_describing("SECRET preview")
    publishable = live_publishable(seo_description: "Saved search line", social_description: "Saved card line")

    html, = render_head(publishable: publishable, recordable: recordable, preview: true)

    assert_equal '<meta name="robots" content="noindex,nofollow">', html
    assert_equal 0, calls.call
    refute_includes html, "SECRET preview"
    refute_includes html, "Saved search line"
    refute_includes html, "Saved card line"
    refute_includes html, 'name="description"'
    refute_includes html, "og:description"
    refute_includes html, "twitter:description"
  end

  def test_recordable_without_publishable_description_keeps_existing_head_tags
    recordable = Struct.new(:title).new("Launch Checklist")
    publishable = live_publishable(
      seo_description: "Search-friendly description",
      social_description: "Social description"
    )

    html, recording = render_head(publishable: publishable, recordable: recordable)

    assert_equal <<~HTML.strip, html.to_s
      <meta name="description" content="Search-friendly description">
      <link rel="canonical" href="https://example.test/published/123/launch-checklist">
      <meta name="robots" content="index,follow">
      <meta property="og:type" content="article">
      <meta property="og:title" content="Social headline">
      <meta property="og:description" content="Social description">
      <meta property="og:url" content="https://example.test/published/123/launch-checklist">
      <meta name="twitter:card" content="summary">
      <meta name="twitter:title" content="Social headline">
      <meta name="twitter:description" content="Social description">
    HTML
    assert_equal "Social description", RecordingStudioPublishable::SharePreview.for(recording).description
    refute recordable.respond_to?(:publishable_description)

    publishable = live_publishable(seo_description: nil, social_description: nil, social_title: nil)
    html, recording = render_head(publishable: publishable, recordable: recordable)

    refute_includes html, 'name="description"'
    refute_includes html, "og:description"
    refute_includes html, "twitter:description"
    assert_includes html, '<meta property="og:title" content="Launch Checklist">'
    assert_equal "", RecordingStudioPublishable::SharePreview.for(recording).description
  end

  private

  def live_publishable(seo_description: nil, social_description: nil, social_title: "Social headline")
    Publishable.new(
      "SEO headline",
      seo_description,
      nil,
      social_title,
      social_description,
      "launch-checklist"
    )
  end

  def recordable_describing(text)
    calls = 0
    recordable = Object.new
    recordable.define_singleton_method(:title) { "Launch Checklist" }
    recordable.define_singleton_method(:publishable_description) do
      calls += 1
      text.respond_to?(:call) ? text.call : text
    end
    [recordable, -> { calls }]
  end

  def render_head(publishable:, recordable:, preview: false, **)
    parent_recording = ParentRecording.new("Folder", recordable)
    publishable_recording = PublishableRecording.new("123", publishable, parent_recording)
    view = ViewContext.new(Struct.new(:base_url).new("https://example.test"))
    view.define_singleton_method(:publishable_preview?) { true } if preview
    html = view.publishable_head_tags(
      publishable_recording: publishable_recording,
      publishable: publishable,
      parent_recordable: recordable,
      **
    )
    recording = Struct.new(:current_publishable, :recordable).new(publishable, recordable)
    [html, recording]
  end

  def tag_content(html, name)
    CGI.unescapeHTML(html.to_s[/meta name="#{name}" content="([^"]*)"/, 1].to_s)
  end

  def property_content(html, property)
    CGI.unescapeHTML(html.to_s[/meta property="#{property}" content="([^"]*)"/, 1].to_s)
  end

  def assert_social_description(html, recording, expected)
    assert_equal expected, property_content(html, "og:description")
    assert_equal expected, tag_content(html, "twitter:description")
    assert_equal expected, RecordingStudioPublishable::SharePreview.for(recording).description
  end
end
