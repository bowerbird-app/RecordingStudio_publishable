# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../test_helper"
require_relative "../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  class ParentRecordableTest < ActiveSupport::TestCase
    test "published returns parent recordables" do
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

      published_ids = Page.published.pluck(:id)

      assert_includes published_ids, published_page.id
      refute_includes published_ids, draft_page.id
    end

    test "status scopes return parent recordables for the matching publishable child state" do
      root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Status workspace"))
      scheduled_article = Article.create!(title: "Scheduled article")
      draft_page = Page.create!(title: "Draft page")
      unpublished_page = Page.create!(title: "Unpublished page")

      scheduled_recording = RecordingStudio::Recording.create!(recordable: scheduled_article, parent_recording: root)
      draft_recording = RecordingStudio::Recording.create!(recordable: draft_page, parent_recording: root)
      unpublished_recording = RecordingStudio::Recording.create!(recordable: unpublished_page, parent_recording: root)

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: scheduled_recording,
        attributes: { slug: "scheduled-page", status: "published", publish_at: 1.day.from_now }
      ).value!

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: draft_recording,
        attributes: { slug: "draft-page", status: "draft" }
      ).value!

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: unpublished_recording,
        attributes: { slug: "unpublished-page", status: "draft" }
      ).value!

      scheduled_ids = Article.scheduled.pluck(:id)
      draft_ids = Page.draft.pluck(:id)

      assert_includes scheduled_ids, scheduled_article.id
      assert_includes draft_ids, draft_page.id
      assert_includes draft_ids, unpublished_page.id

      assert scheduled_article.reload.scheduled?
      refute scheduled_article.published?
      refute scheduled_article.draft?
      refute scheduled_article.unpublished?

      assert draft_page.reload.draft?
      refute draft_page.published?
      refute draft_page.scheduled?

      assert unpublished_page.draft?
      refute unpublished_page.unpublished?
      refute unpublished_page.published?
      refute unpublished_page.scheduled?
    end
  end
end
