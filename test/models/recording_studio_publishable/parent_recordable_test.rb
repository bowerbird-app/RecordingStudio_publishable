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

    test "scheduled_in accepts both a range and a time cutoff" do
      root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Scheduled in workspace"))
      near_future_article = Article.create!(title: "Near future article")
      far_future_article = Article.create!(title: "Far future article")

      near_recording = RecordingStudio::Recording.create!(recordable: near_future_article, parent_recording: root)
      far_recording = RecordingStudio::Recording.create!(recordable: far_future_article, parent_recording: root)

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: near_recording,
        attributes: { slug: "near-future-article", status: "published", publish_at: 1.day.from_now }
      ).value!

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: far_recording,
        attributes: { slug: "far-future-article", status: "published", publish_at: 5.weeks.from_now }
      ).value!

      by_range_ids = Article.scheduled_in(Time.current..2.weeks.from_now).pluck(:id)
      by_cutoff_ids = Article.scheduled_in(2.weeks.from_now).pluck(:id)

      assert_includes by_range_ids, near_future_article.id
      refute_includes by_range_ids, far_future_article.id

      assert_includes by_cutoff_ids, near_future_article.id
      refute_includes by_cutoff_ids, far_future_article.id
    end

    test "published_in accepts both a range and a time cutoff" do
      root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Published in workspace"))
      recent_page = Page.create!(title: "Recent published page")
      old_page = Page.create!(title: "Old published page")

      recent_recording = RecordingStudio::Recording.create!(recordable: recent_page, parent_recording: root)
      old_recording = RecordingStudio::Recording.create!(recordable: old_page, parent_recording: root)

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: recent_recording,
        attributes: { slug: "recent-published-page", status: "published", publish_at: 1.day.ago }
      ).value!

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: old_recording,
        attributes: { slug: "old-published-page", status: "published", publish_at: 6.weeks.ago }
      ).value!

      by_range_ids = Page.published_in(2.weeks.ago..Time.current).pluck(:id)
      by_cutoff_ids = Page.published_in(Time.current).pluck(:id)

      assert_includes by_range_ids, recent_page.id
      refute_includes by_range_ids, old_page.id

      assert_includes by_cutoff_ids, recent_page.id
      refute_includes by_cutoff_ids, old_page.id
    end

    test "unpublished_in accepts both a range and a time cutoff" do
      root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Unpublished in workspace"))
      recent_page = Page.create!(title: "Recent unpublished page")
      old_page = Page.create!(title: "Old unpublished page")

      recent_recording = RecordingStudio::Recording.create!(recordable: recent_page, parent_recording: root)
      old_recording = RecordingStudio::Recording.create!(recordable: old_page, parent_recording: root)

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: recent_recording,
        attributes: { slug: "recent-unpublished-page", status: "draft", unpublish_at: 2.days.from_now }
      ).value!

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: old_recording,
        attributes: { slug: "old-unpublished-page", status: "draft", unpublish_at: 5.weeks.from_now }
      ).value!

      by_range_ids = Page.unpublished_in(Time.current..2.weeks.from_now).pluck(:id)
      by_cutoff_ids = Page.unpublished_in(2.weeks.from_now).pluck(:id)

      assert_includes by_range_ids, recent_page.id
      refute_includes by_range_ids, old_page.id

      assert_includes by_cutoff_ids, recent_page.id
      refute_includes by_cutoff_ids, old_page.id
    end

    test "published_url returns canonical path for currently published recordables" do
      root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Published URL workspace"))
      page = Page.create!(title: "Published URL page")
      page_recording = RecordingStudio::Recording.create!(recordable: page, parent_recording: root)

      publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: page_recording,
        attributes: { slug: "published-url-page", status: "published" }
      ).value!

      assert_equal "/published/#{publishable_recording.id}/published-url-page", page.published_url
    end

    test "published_url returns nil for non-published recordables" do
      root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Draft URL workspace"))
      page = Page.create!(title: "Draft URL page")
      page_recording = RecordingStudio::Recording.create!(recordable: page, parent_recording: root)

      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: page_recording,
        attributes: { slug: "draft-url-page", status: "draft" }
      ).value!

      assert_nil page.published_url
    end
  end
end
