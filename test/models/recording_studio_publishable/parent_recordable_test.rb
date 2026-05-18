# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../test_helper"
require_relative "../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  class ParentRecordableTest < ActiveSupport::TestCase
    test "currently_published return parent recordables" do
      root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Scope workspace"))
      published_page = Page.create!(title: "Published page")
      draft_page = Page.create!(title: "Draft page")
      published_recording = RecordingStudio::Recording.create!(recordable: published_page, parent_recording: root)
      draft_recording = RecordingStudio::Recording.create!(recordable: draft_page, parent_recording: root)

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: published_recording,
        attributes: { slug: "published-page", status: "published" }
      ).value!

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: draft_recording,
        attributes: { slug: "draft-page", status: "draft" }
      ).value!

      assert_equal [published_page.id], Page.currently_published.pluck(:id)
    end

    test "status scopes return parent recordables for the matching publishable child state" do
      root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Status workspace"))
      scheduled_page = Page.create!(title: "Scheduled page")
      draft_page = Page.create!(title: "Draft page")
      unpublished_page = Page.create!(title: "Unpublished page")

      scheduled_recording = RecordingStudio::Recording.create!(recordable: scheduled_page, parent_recording: root)
      draft_recording = RecordingStudio::Recording.create!(recordable: draft_page, parent_recording: root)
      unpublished_recording = RecordingStudio::Recording.create!(recordable: unpublished_page, parent_recording: root)

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: scheduled_recording,
        attributes: { slug: "scheduled-page", status: "scheduled", publish_at: 1.day.from_now }
      ).value!

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: draft_recording,
        attributes: { slug: "draft-page", status: "draft" }
      ).value!

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: unpublished_recording,
        attributes: { slug: "unpublished-page", status: "unpublished" }
      ).value!

      assert_equal [scheduled_page.id], Page.scheduled.pluck(:id)
      assert_equal [draft_page.id], Page.draft.pluck(:id)
      assert_equal [unpublished_page.id], Page.unpublished.pluck(:id)
    end
  end
end
