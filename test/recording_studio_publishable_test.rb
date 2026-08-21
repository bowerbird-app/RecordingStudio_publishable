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
  end

  def test_dummy_home_page_mentions_publishable_demo
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, "Dummy pages"
    assert_includes view_source, "Add Page"
    assert_includes view_source, "Public path"
  end
end
