# frozen_string_literal: true

require "test_helper"

class RecordingStudioPublishableTest < Minitest::Test
  def test_version_exists
    refute_nil ::RecordingStudioPublishable::VERSION
  end

  def test_readme_describes_publishable_addon
    readme_path = File.expand_path("../README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "RecordingStudio_publishable"
    assert_includes readme_source, "publishable child recording"
  end

  def test_dummy_home_page_mentions_publishable_demo
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, "Recording Studio Publishable demo"
    assert_includes view_source, "Edit publishable info"
    assert_includes view_source, "View public route"
  end
end
