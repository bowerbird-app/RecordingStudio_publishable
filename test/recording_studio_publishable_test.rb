# frozen_string_literal: true

require "test_helper"

class RecordingStudioPublishableTest < Minitest::Test
  def test_version_exists
    refute_nil ::RecordingStudioPublishable::VERSION
  end

  def test_readme_describes_publishable_addon
    readme_path = File.expand_path("../README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "recording_studio_publishable"
    assert_includes readme_source, "RecordingStudio::Capabilities::Publishable.to"
    assert_includes readme_source, "published.recording_studio_publishable"
    assert_includes readme_source, "RecordingStudioPublishable.subscribe"
    refute_includes readme_source, "# GemTemplate"
    refute_includes readme_source, "recording_studio_publishable("
    refute_includes readme_source, "ParentRecordable"
  end

  def test_dummy_home_page_uses_default_layout_table
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)
    layout_source = File.read(
      File.expand_path("dummy/app/views/layouts/recording_studio/default_layout.html.erb", __dir__)
    )
    devise_layout = File.read(
      File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__)
    )

    assert_includes File.read(
      File.expand_path("dummy/app/views/layouts/flat_pack/_top_nav.html.erb", __dir__)
    ), "dummy_language_selector"
    assert_includes view_source, "dummy_page_nav"
    assert_includes view_source, "FlatPack::Table::Component"
    assert_includes view_source, "text: \"Page\""
    assert_includes view_source, "icon: \"plus\""
    refute_includes view_source, "Add page"
    refute_includes view_source, "Dummy publishables"
    assert_includes layout_source, "dummy_document_attributes"
    assert_includes layout_source, "dummy_language_selector"
    assert_includes layout_source, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes devise_layout, "dummy_document_attributes"
  end

  def test_publish_search_screen_uses_plain_field_labels
    view_source = File.read(
      File.expand_path("../app/views/recording_studio_publishable/publishables/search.html.erb", __dir__)
    )

    refute_includes view_source, "FlatPack::Accordion::Component"
    refute_includes view_source, "title: \"Search engines\""
    refute_includes view_source, "Title in search"
    refute_includes view_source, "Description in search"
    refute_includes view_source, "Search listing"
    refute_includes view_source, "Hide from search"
    refute_includes view_source, "Original URL"
    refute_includes view_source, "Keep this out of search engines"
    assert_includes view_source, "FlatPack::Collapse::Component"
    assert_includes view_source, "FlatPack::Checkbox::Component"
    assert_includes view_source, 'publishable_t("form.advanced")'
    assert_includes view_source, 'publishable_t("form.canonical_url")'
    assert_includes view_source, 'publishable_t("form.canonical_help")'
    assert_includes view_source, 'publishable_t("form.noindex")'
    assert_includes view_source, 'publishable_t("form.noindex_help")'
    assert_includes view_source, 'publishable_t("form.title")'
    assert_includes view_source, 'publishable_t("form.description")'
    assert_includes view_source, 'publishable_t("form.description_help")'
    title_index = view_source.index('publishable_t("form.title")')
    slug_index = view_source.index('publishable_t("form.slug")')
    description_index = view_source.index('publishable_t("form.description")')
    noindex_index = view_source.index('publishable_t("form.noindex")')
    canonical_index = view_source.index('publishable_t("form.canonical_url")')
    assert title_index < slug_index
    assert slug_index < description_index
    assert description_index < noindex_index
    assert noindex_index < canonical_index
  end

  def test_publish_jobs_omits_schedule_when_scheduling_is_off
    listed = RecordingStudioPublishable::PublishJobs.listed(schedule_enabled: false)

    refute_includes listed.map(&:key), :schedule
    assert_equal %i[search social], listed.map(&:key)
  end

  def test_summary_card_and_published_fallback_use_i18n_keys
    summary = File.read(
      File.expand_path("../app/views/recording_studio_publishable/components/_summary_card.html.erb", __dir__)
    )
    published = File.read(
      File.expand_path("../app/views/recording_studio_publishable/published/show.html.erb", __dir__)
    )
    layout = File.read(
      File.expand_path("../app/views/layouts/recording_studio_publishable/application.html.erb", __dir__)
    )

    assert_includes summary, 'publishable_t("summary.title")'
    assert_includes summary, 'publishable_t("summary.subtitle")'
    assert_includes summary, 'publishable_t("summary.empty")'
    refute_includes summary, 'title: "Summary"'
    assert_includes published, 'publishable_t("published.fallback_subtitle")'
    assert_includes published, 'publishable_t("published.parent_recordable")'
    assert_includes published, 'publishable_t("published.current_title")'
    refute_includes published, "Published from the parent recording's current recordable."
    assert_includes layout, 'publishable_t("layout.title", default: "Recording Studio Publishable")'
  end
end
