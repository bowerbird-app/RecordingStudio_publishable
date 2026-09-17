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

    assert_includes view_source, "dummy_page_nav"
    assert_includes view_source, "FlatPack::Table::Component"
    assert_includes view_source, "text: \"Page\""
    assert_includes view_source, "icon: \"plus\""
    refute_includes view_source, "Add page"
    refute_includes view_source, "Dummy publishables"
    assert_includes layout_source, '<html data-theme="rounded">'
    assert_includes layout_source, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes devise_layout, '<html data-theme="rounded">'
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
    assert_includes view_source, "FlatPack::Collapse::Component"
    assert_includes view_source, "FlatPack::Checkbox::Component"
    assert_includes view_source, "title: \"Advanced\""
    assert_includes view_source, "label: \"Original URL\""
    assert_includes view_source, "Leave this blank unless this page is replacing an older address."
    assert_includes view_source, "Paste that old full https:// address so search still treats this as the same page."
    assert_includes view_source, "label: \"Hide from search\""
    assert_includes view_source, "They only see this while the page is live."
    assert_includes view_source, "label: \"Title\""
    assert_includes view_source, "label: \"Description\""
    assert_includes view_source, "help_text: \"The line under the title in search results.\""
    title_index = view_source.index("label: \"Title\"")
    slug_index = view_source.index("label: \"Slug\"")
    description_index = view_source.index("label: \"Description\"")
    hide_index = view_source.index("label: \"Hide from search\"")
    assert title_index < slug_index
    assert slug_index < description_index
    assert description_index < hide_index
  end

  def test_publish_jobs_omits_schedule_when_scheduling_is_off
    listed = RecordingStudioPublishable::PublishJobs.listed(schedule_enabled: false)

    refute_includes listed.map(&:key), :schedule
    assert_equal %i[search social], listed.map(&:key)
  end
end
