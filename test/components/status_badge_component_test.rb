# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "nokogiri"
require "rails/test_help"

class StatusBadgeComponentTest < ActionDispatch::IntegrationTest
  setup do
    @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Status badge workspace"))
  end

  test "draft badge renders draft copy" do
    html = render_badge(status: "draft", slug: "draft-badge")

    assert_equal "Draft", badge_text(html)
  end

  test "published badge renders published copy" do
    html = render_badge(status: "published", slug: "published-badge")

    assert_equal "Published", badge_text(html)
  end

  test "scheduled badge renders scheduled copy" do
    html = render_badge(status: "published", slug: "scheduled-badge", publish_at: 1.day.from_now)

    assert_equal "Scheduled", badge_text(html)
  end

  test "partial and component share the same status copy" do
    recording = recording_with_publishable(status: "published", slug: "shared-badge")
    publishable = recording.current_publishable
    component_html = ApplicationController.render(
      RecordingStudioPublishable::StatusBadge::Component.new(publishable: publishable),
      layout: false
    )
    partial_html = ApplicationController.render(
      partial: "recording_studio_publishable/components/status_badge",
      locals: { publishable: publishable },
      layout: false
    )

    assert_equal badge_text(component_html), badge_text(partial_html)
  end

  private

  def render_badge(status:, slug:, publish_at: nil)
    recording = recording_with_publishable(status: status, slug: slug, publish_at: publish_at)
    ApplicationController.render(
      RecordingStudioPublishable::StatusBadge::Component.new(publishable: recording.current_publishable),
      layout: false
    )
  end

  def recording_with_publishable(status:, slug:, publish_at: nil)
    recording = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: slug),
      parent_recording: @root
    )
    attributes = { slug: slug, status: status }
    attributes[:publish_at] = publish_at if publish_at
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: attributes
    )
    recording
  end

  def badge_text(html)
    Nokogiri::HTML(html).at_css("span, div")&.text&.strip
  end
end
