# frozen_string_literal: true

require "test_helper"

class RoutingTest < Minitest::Test
  PublishableRecording = Struct.new(:id, :recordable, :parent_recording)
  ParentRecording = Struct.new(:recordable_type)
  Publishable = Struct.new(:slug)

  def setup
    RecordingStudioPublishable.reset_configuration!
  end

  def test_path_for_uses_the_registered_template
    RecordingStudioPublishable.configuration.register_public_path("Page", path: "/pages/:uuid/:slug")

    recording = PublishableRecording.new("123", Publishable.new("hello-world"), ParentRecording.new("Page"))

    assert_equal "/pages/123/hello-world",
                 RecordingStudioPublishable::Routing.path_for(publishable_recording: recording)
  end

  def test_url_for_uses_the_same_template_source_of_truth
    recording = PublishableRecording.new("123", Publishable.new("hello-world"), ParentRecording.new("Page"))

    assert_equal "https://example.test/published/123/hello-world", RecordingStudioPublishable::Routing.url_for(
      publishable_recording: recording,
      host: "example.test",
      protocol: "https"
    )
  end

  def test_register_public_renderer_path_updates_routing_template
    RecordingStudioPublishable.configuration.register_public_renderer(
      "Article",
      controller: "articles",
      action: :show,
      path: "/blogs/:uuid/:slug"
    )

    recording = PublishableRecording.new("123", Publishable.new("hello-world"), ParentRecording.new("Article"))

    assert_equal "/blogs/123/hello-world",
                 RecordingStudioPublishable::Routing.path_for(publishable_recording: recording)
  end
end
