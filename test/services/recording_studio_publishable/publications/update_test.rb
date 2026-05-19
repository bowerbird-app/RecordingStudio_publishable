# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../../test_helper"
require_relative "../../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  module Services
    module Publishables
      class UpdateTest < ActiveSupport::TestCase
        setup do
          @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Workspace"))
          @parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Landing"),
                                                                 parent_recording: @root)
        end

        test "creates a revised publishable recordable with provided attributes" do
          result = Update.call(
            parent_recording: @parent_recording,
            attributes: {
              slug: "landing-page",
              status: "published",
              seo_title: "Landing page",
              canonical_url: "https://example.test/landing-page"
            }
          )

          assert result.success?
          publishable = result.value.recordable
          assert_equal "landing-page", publishable.slug
          assert_equal "published", publishable.status
          assert_equal "Landing page", publishable.seo_title
          assert_equal "https://example.test/landing-page", publishable.canonical_url
          assert publishable.published?
        end

        test "stores publish timestamps in utc and respects the configured display zone" do
          original_time_zone = RecordingStudioPublishable.configuration.default_time_zone
          RecordingStudioPublishable.configuration.default_time_zone = "Pacific Time (US & Canada)"

          result = Update.call(
            parent_recording: @parent_recording,
            attributes: {
              slug: "landing-page",
              status: "published",
              publish_at: "2026-05-20 09:00",
              time_zone: "Pacific Time (US & Canada)"
            }
          )

          assert result.success?
          publishable = result.value.recordable

          assert_equal "Pacific Time (US & Canada)", publishable.effective_time_zone
          assert_equal "UTC", publishable.publish_at.time_zone.name
          assert publishable.scheduled_for_future?
        ensure
          RecordingStudioPublishable.configuration.default_time_zone = original_time_zone
        end

        test "published toggle true sets published state and publish_at when missing" do
          freeze_time do
            result = Update.call(
              parent_recording: @parent_recording,
              attributes: { slug: "landing-page", published_toggle: "1" }
            )

            assert result.success?
            publishable = result.value.recordable
            assert_equal "published", publishable.status
            assert_in_delta Time.current.to_f, publishable.publish_at.to_f, 1.0
            assert_nil publishable.unpublish_at
          end
        end

        test "published toggle false sets draft state and unpublish_at now" do
          freeze_time do
            result = Update.call(
              parent_recording: @parent_recording,
              attributes: { slug: "landing-page", published_toggle: "0" }
            )

            assert result.success?
            publishable = result.value.recordable
            assert_equal "draft", publishable.status
            assert_in_delta Time.current.to_f, publishable.unpublish_at.to_f, 1.0
            refute publishable.currently_published?
          end
        end

        test "republishing after draft sets a new publish_at and clears unpublish_at" do
          freeze_time do
            first_publish = Update.call(
              parent_recording: @parent_recording,
              attributes: { slug: "landing-page", published_toggle: "1" }
            )

            assert first_publish.success?
            first_publish_time = first_publish.value.recordable.publish_at

            travel 10.minutes
            unpublish = Update.call(
              parent_recording: @parent_recording,
              attributes: { slug: "landing-page", published_toggle: "0" }
            )

            assert unpublish.success?
            assert_equal "draft", unpublish.value.recordable.status
            assert unpublish.value.recordable.unpublish_at.present?

            travel 5.minutes
            republish = Update.call(
              parent_recording: @parent_recording,
              attributes: { slug: "landing-page", published_toggle: "1" }
            )

            assert republish.success?
            publishable = republish.value.recordable
            assert_equal "published", publishable.status
            assert publishable.publish_at > first_publish_time
            assert_nil publishable.unpublish_at
          end
        end

        test "draft state with future publish_at does not become live" do
          future_publish_at = "2099-05-20 09:00"

          result = Update.call(
            parent_recording: @parent_recording,
            attributes: {
              slug: "landing-page",
              status: "draft",
              publish_at: future_publish_at
            }
          )

          assert result.success?
          publishable = result.value.recordable
          assert_equal "draft", publishable.status
          assert publishable.publish_at.future?
          refute publishable.currently_published?
        end

        test "returns a failure when publish_at is invalid" do
          result = Update.call(
            parent_recording: @parent_recording,
            attributes: { slug: "landing-page", publish_at: "not-a-time" }
          )

          assert result.failure?
          assert_equal "Publish at is invalid", result.error
        end

        test "stores the selected social image attachment recording" do
          publishable_recording = Update.call(
            parent_recording: @parent_recording,
            attributes: { slug: "landing-page" }
          ).value!
          attachment_recording = create_attachment_recording(parent_recording: publishable_recording)

          result = Update.call(
            parent_recording: @parent_recording,
            attributes: {
              slug: "landing-page",
              social_image_attachment_recording_id: attachment_recording.id
            }
          )

          assert result.success?
          assert_equal attachment_recording.id, result.value.recordable.social_image_attachment_recording_id
        end

        test "returns a failure when the selected social image is not a direct attachment child" do
          Update.call(parent_recording: @parent_recording, attributes: { slug: "landing-page" }).value!

          result = Update.call(
            parent_recording: @parent_recording,
            attributes: { slug: "landing-page", social_image_attachment_recording_id: SecureRandom.uuid }
          )

          assert result.failure?
          assert_equal "Social image is invalid", result.error
        end

        private

        def create_attachment_recording(parent_recording:)
          blob = ActiveStorage::Blob.create_and_upload!(
            io: StringIO.new("image-bytes"),
            filename: "hero.png",
            content_type: "image/png"
          )
          attachment = RecordingStudioAttachable::Attachment.build_from_blob(blob: blob, name: "Hero image")
          attachment.save!

          RecordingStudio::Recording.create!(recordable: attachment, parent_recording: parent_recording)
        end
      end
    end
  end
end
