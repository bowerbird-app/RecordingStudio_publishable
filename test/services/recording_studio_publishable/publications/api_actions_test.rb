# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../../test_helper"
require_relative "../../../dummy/config/environment"
require "rails/test_help"
require "stringio"

module RecordingStudioPublishable
  module Api
    class ActionsTest < ActiveSupport::TestCase
      ActionContext = Struct.new(:recording, :api_client, :params, keyword_init: true)

      setup do
        @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Workspace"))
        @parent_recording = RecordingStudio::Recording.create!(recordable: Article.create!(title: "Landing"),
                                                               parent_recording: @root)
      end

      test "publish turns a draft parent into published" do
        outcome = nil
        transitions = with_transition_capture { outcome = perform(:publish) }

        assert_equal ["publish"], transitions
        assert_equal "published", outcome.publishable.status
        assert_in_delta Time.current.to_f, outcome.publishable.publish_at.to_f, 1.0
        assert_equal [@parent_recording.id.to_s, "published"], snapshot_id_and_status(outcome)
      end

      test "unpublish turns a published parent into draft" do
        perform(:publish)
        outcome = nil
        transitions = with_transition_capture { outcome = perform(:unpublish) }

        assert_equal ["unpublish"], transitions
        assert_equal "draft", outcome.publishable.status
        assert_nil outcome.publishable.publish_at
      end

      test "update_publishable writes publishable columns" do
        attachment = image_attachment_for_parent
        outcome = perform(:update_publishable, params: written_columns(attachment))
        record = outcome.publishable

        assert_equal "launch", record.slug
        assert_equal Time.utc(2099, 5, 2, 15, 0, 0).to_i, record.publish_at.to_i
        assert_equal Time.utc(2099, 5, 3, 15, 0, 0).to_i, record.unpublish_at.to_i
        assert_equal "UTC", record.time_zone
        assert_equal "Launch", record.seo_title
        assert_equal "A launch line.", record.seo_description
        assert_equal "https://example.test/launch", record.canonical_url
        assert_equal "noindex,follow", record.meta_robots
        assert_equal "Share launch", record.social_title
        assert_equal "Card line.", record.social_description
        assert_equal attachment.id, record.social_image_attachment_recording_id
      end

      test "update_publishable rejects an invalid social image id" do
        perform(:update_publishable, params: { slug: "launch" })

        error_class = if defined?(RecordingStudioApi::InvalidActionInputError)
                        RecordingStudioApi::InvalidActionInputError
                      else
                        StandardError
                      end
        error = assert_raises(error_class) do
          perform(:update_publishable, params: { social_image_attachment_recording_id: SecureRandom.uuid })
        end

        assert_equal "Social image is invalid", error.message
        assert_nil @parent_recording.reload.current_publishable.social_image_attachment_recording_id
      end

      test "update_publishable does not persist publish_at when schedule is disabled" do
        with_capability_overrides(Article, schedule: false) do
          outcome = perform(:update_publishable, params: { slug: "held", publish_at: "2099-01-02T03:04:05Z" })

          assert_equal "held", outcome.publishable.slug
          assert_nil outcome.publishable.publish_at
        end
      end

      test "update_publishable does not persist seo_title when seo is disabled" do
        with_capability_overrides(Article, seo: false) do
          outcome = perform(:update_publishable, params: {
                              slug: "held",
                              seo_title: "Search title",
                              canonical_url: "https://example.test/held"
                            })

          assert_nil outcome.publishable.seo_title
          assert_equal "https://example.test/held", outcome.publishable.canonical_url
        end
      end

      test "scheduled status stores published and the snapshot status is scheduled" do
        outcome = perform(:update_publishable, params: {
                            slug: "later",
                            status: "scheduled",
                            publish_at: "2099-12-01T15:00",
                            time_zone: "UTC"
                          })

        assert_equal "published", outcome.publishable.status
        assert_equal Time.utc(2099, 12, 1, 15, 0, 0).to_i, outcome.publishable.publish_at.to_i
        assert_equal [@parent_recording.id.to_s, "scheduled"], snapshot_id_and_status(outcome)
      end

      test "performer rejects a publishable child recording" do
        child = perform(:publish).child_recording
        count = RecordingStudioPublishable::Publishable.count

        error = assert_raises(StandardError) { perform(:publish, recording: child) }

        assert_equal "publish applies to the parent recording, not the publishable child", error.message
        assert_equal count, RecordingStudioPublishable::Publishable.count
        assert_nil child.reload.publishable_child_recording
      end

      private

      def perform(action_name, recording: @parent_recording, params: {})
        Perform::Bound.new(action_name).call(ActionContext.new(recording: recording, api_client: nil, params: params))
      end

      def snapshot_id_and_status(outcome)
        body = PublishableSnapshot.call(outcome)
        [body.fetch(:id), body.fetch(:status)]
      end

      def with_transition_capture
        service = RecordingStudioPublishable::Services::Publishables::Transition
        original = nil
        seen = []
        original = service.method(:call)
        service.define_singleton_method(:call) do |**kwargs|
          seen << kwargs.fetch(:transition)
          original.call(**kwargs)
        end
        yield
        seen
      ensure
        service.define_singleton_method(:call, original) if original
      end

      def with_capability_overrides(recordable_class, **overrides)
        previous = nil
        previous = RecordingStudio.capability_options(:publishable, for: recordable_class).to_h.symbolize_keys
        RecordingStudio.set_capability_options(:publishable, on: recordable_class, **previous.merge(overrides))
        yield
      ensure
        RecordingStudio.set_capability_options(:publishable, on: recordable_class, **previous) if previous
      end

      def written_columns(attachment)
        {
          slug: "launch",
          publish_at: "2099-05-02T15:00",
          unpublish_at: "2099-05-03T15:00",
          time_zone: "UTC",
          seo_title: "Launch",
          seo_description: "A launch line.",
          canonical_url: "https://example.test/launch",
          meta_robots: "noindex,follow",
          social_title: "Share launch",
          social_description: "Card line.",
          social_image_attachment_recording_id: attachment.id
        }
      end

      def image_attachment_for_parent
        outcome = perform(:update_publishable, params: { slug: "launch" })
        create_attachment_recording(parent_recording: outcome.child_recording)
      end

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
