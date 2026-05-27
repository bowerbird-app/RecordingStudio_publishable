# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../test_helper"
require_relative "../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  class RecordingExtensionsTest < ActiveSupport::TestCase
    setup do
      root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Workspace"))
      @parent_recording = RecordingStudio::Recording.create!(
        recordable: Page.create!(title: "Landing"),
        parent_recording: root
      )
    end

    test "delegates publish-state booleans to the current publishable" do
      result = RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: @parent_recording,
        attributes: {
          slug: "landing-page",
          status: "draft"
        }
      )

      assert result.success?

      publishable = @parent_recording.current_publishable

      assert_equal publishable.currently_published?, @parent_recording.currently_published?
      assert_equal publishable.published?, @parent_recording.published?
      assert_equal publishable.draft_state?, @parent_recording.draft?
      assert_equal publishable.scheduled_for_future?, @parent_recording.scheduled?
      assert_equal publishable.published_state?, @parent_recording.published_state?
      assert_equal publishable.draft_state?, @parent_recording.draft_state?
      assert_equal publishable.scheduled_for_future?, @parent_recording.scheduled_for_future?
      assert_equal publishable.previously_published?, @parent_recording.previously_published?
      assert_equal publishable.unpublished?, @parent_recording.unpublished?
      assert_equal publishable.social_image_supported?, @parent_recording.social_image_supported?
      assert_equal publishable.social_image_attached?, @parent_recording.social_image_attached?

      scheduled_result = RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: @parent_recording,
        attributes: {
          slug: "landing-page",
          status: "published",
          publish_at: 1.day.from_now
        }
      )
      assert scheduled_result.success?

      publishable = @parent_recording.current_publishable

      assert_equal publishable.currently_published?, @parent_recording.currently_published?
      assert_equal publishable.published?, @parent_recording.published?
      assert_equal publishable.draft_state?, @parent_recording.draft?
      assert_equal publishable.scheduled_for_future?, @parent_recording.scheduled?
      assert_equal publishable.published_state?, @parent_recording.published_state?
      assert_equal publishable.draft_state?, @parent_recording.draft_state?
      assert_equal publishable.scheduled_for_future?, @parent_recording.scheduled_for_future?
      assert_equal publishable.previously_published?, @parent_recording.previously_published?
      assert_equal publishable.unpublished?, @parent_recording.unpublished?
      assert_equal publishable.social_image_supported?, @parent_recording.social_image_supported?
      assert_equal publishable.social_image_attached?, @parent_recording.social_image_attached?
    end

    test "boolean helpers return false when no publishable child exists" do
      refute @parent_recording.currently_published?
      refute @parent_recording.published?
      refute @parent_recording.draft?
      refute @parent_recording.scheduled?
      refute @parent_recording.published_state?
      refute @parent_recording.draft_state?
      refute @parent_recording.scheduled_for_future?
      refute @parent_recording.previously_published?
      refute @parent_recording.unpublished?
      refute @parent_recording.social_image_supported?
      refute @parent_recording.social_image_attached?
    end

    test "query aliases return recording relations" do
      result = RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: @parent_recording,
        attributes: {
          slug: "landing-page",
          status: "published",
          publish_at: 10.days.from_now
        }
      )
      assert result.success?

      assert_includes RecordingStudio::Recording.scheduled.to_a, @parent_recording
      assert_includes RecordingStudio::Recording.scheduled_in(2.weeks.from_now).to_a, @parent_recording
      assert_includes RecordingStudio::Recording.scheduled_between(Time.current..2.weeks.from_now).to_a, @parent_recording
      refute_includes RecordingStudio::Recording.published.to_a, @parent_recording
      refute_includes RecordingStudio::Recording.draft.to_a, @parent_recording
      refute_includes RecordingStudio::Recording.unpublished.to_a, @parent_recording
    end
  end
end