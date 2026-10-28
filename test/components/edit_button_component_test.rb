# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "nokogiri"
require "rails/test_help"

class EditButtonComponentTest < ActionDispatch::IntegrationTest
  setup do
    @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Edit button workspace"))
  end

  test "host class merges onto the status classes" do
    recording = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: "Draft edit button"),
      parent_recording: @root
    )
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "draft-edit-button", status: "draft" }
    )

    html = ApplicationController.render(
      RecordingStudioPublishable::EditButtonComponent.new(
        recording: recording,
        class: "host-edit-button",
        title: "Edit publish settings"
      ),
      layout: false
    )
    link = Nokogiri::HTML(html).at_css("a")

    assert_includes link["class"], "host-edit-button"
    assert_includes link["class"], "inline-flex"
    assert_includes link["class"], "border-[var(--button-secondary-border-color)]"
    assert_equal "Edit publish settings", link["title"]
    assert_includes link.text, "Draft"
  end

  test "published recording renders published status copy" do
    recording = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: "Published edit button"),
      parent_recording: @root
    )
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "published-edit-button", status: "published" }
    )

    html = ApplicationController.render(
      RecordingStudioPublishable::EditButtonComponent.new(recording: recording),
      layout: false
    )

    assert_includes Nokogiri::HTML(html).at_css("a").text, "Published"
  end

  test "scheduled recording renders scheduled status copy" do
    recording = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: "Scheduled edit button"),
      parent_recording: @root
    )
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: "scheduled-edit-button", status: "published", publish_at: 2.days.from_now }
    )

    html = ApplicationController.render(
      RecordingStudioPublishable::EditButtonComponent.new(recording: recording),
      layout: false
    )

    assert_includes Nokogiri::HTML(html).at_css("a").text, "Scheduled"
  end
end
