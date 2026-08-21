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
    assert_includes view_source, "Add page"
    refute_includes view_source, "Dummy publishables"
    assert_includes layout_source, '<html data-theme="rounded">'
    assert_includes layout_source, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes devise_layout, '<html data-theme="rounded">'
  end
end
