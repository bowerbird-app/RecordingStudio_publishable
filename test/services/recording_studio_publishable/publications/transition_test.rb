# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../../test_helper"
require_relative "../../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  module Services
    module Publishables
      class TransitionTest < ActiveSupport::TestCase
        setup do
          @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Workspace"))
          @parent_recording = RecordingStudio::Recording.create!(
            recordable: Article.create!(title: "Landing"),
            parent_recording: @root
          )
        end

        test "a second publish on a live parent leaves publish_at and unpublish_at unchanged" do
          freeze_time do
            Transition.call(parent_recording: @parent_recording, transition: "publish")
            Update.call(
              parent_recording: @parent_recording,
              attributes: { unpublish_at: 1.day.from_now.iso8601, time_zone: "UTC" }
            )
            publishable = @parent_recording.reload.current_publishable
            publish_at = publishable.publish_at
            unpublish_at = publishable.unpublish_at

            travel 1.minute
            result = Transition.call(parent_recording: @parent_recording, transition: "publish")

            assert result.success?
            assert_equal publish_at, result.value.recordable.publish_at
            assert_equal unpublish_at, result.value.recordable.unpublish_at
          end
        end

        test "a second unpublish on a draft parent does not write" do
          freeze_time do
            Update.call(parent_recording: @parent_recording, attributes: { slug: "held" })
            child = @parent_recording.reload.publishable_child_recording
            publishable = child.recordable
            updated_at = publishable.updated_at

            travel 1.minute
            result = Transition.call(parent_recording: @parent_recording, transition: "unpublish")

            assert result.success?
            assert_equal child.id, result.value.id
            assert_equal "draft", publishable.reload.status
            assert_nil publishable.publish_at
            assert_nil publishable.unpublish_at
            assert_equal updated_at, publishable.updated_at
          end
        end

        test "unpublish without a publishable child does not create one" do
          count = RecordingStudioPublishable::Publishable.count

          result = Transition.call(parent_recording: @parent_recording, transition: "unpublish")

          assert result.success?
          assert_nil result.value
          assert_nil @parent_recording.reload.publishable_child_recording
          assert_equal count, RecordingStudioPublishable::Publishable.count
        end

        test "unpublish of a scheduled parent writes draft and clears times" do
          Update.call(
            parent_recording: @parent_recording,
            attributes: {
              slug: "later",
              status: "scheduled",
              publish_at: "2099-12-01T15:00",
              time_zone: "UTC"
            }
          )

          result = Transition.call(parent_recording: @parent_recording, transition: "unpublish")

          assert result.success?
          publishable = result.value.recordable
          assert_equal "draft", publishable.status
          assert_nil publishable.publish_at
          assert_nil publishable.unpublish_at
        end
      end
    end
  end
end
