# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../test_helper"
require_relative "../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  class PublicReadTest < ActiveSupport::TestCase
    setup do
      @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public read"))
      @previous_url_options = Rails.application.routes.default_url_options.dup
    end

    teardown do
      Rails.application.routes.default_url_options = @previous_url_options
    end

    test "a live page returns the child path and an absolute url when a host is configured" do
      Rails.application.routes.default_url_options = { host: "press.test", protocol: "https" }
      recording = publish_page("Live page", slug: "live-page", status: "published")
      child = recording.publishable_child_recording
      read = recording.publishable_public_read

      assert_equal RecordingStudioPublishable::PublicRead.for(recording), read
      assert_equal "published", read[:status]
      assert_equal "live-page", read[:slug]
      assert_equal recording.current_publishable.publish_at.iso8601, read[:publish_at]
      assert_nil read[:unpublish_at]
      assert_equal "/published/#{child.id}/live-page", read[:public_path]
      assert_equal "https://press.test/published/#{child.id}/live-page", read[:public_url]
    end

    test "a live page returns the path and an empty url when no host is configured" do
      Rails.application.routes.default_url_options = {}
      recording = publish_page("Path only", slug: "path-only", status: "published")
      child = recording.publishable_child_recording
      read = recording.publishable_public_read

      assert_equal "/published/#{child.id}/path-only", read[:public_path]
      assert_nil read[:public_url]
    end

    test "draft future expired and trashed recordings expose no public link" do
      Rails.application.routes.default_url_options = { host: "press.test", protocol: "https" }
      draft = publish_page("Draft page", slug: "draft-page", status: "draft")
      future = publish_page(
        "Future page",
        slug: "future-page",
        status: "published",
        publish_at: 1.hour.from_now,
        time_zone: "UTC"
      )
      expired = publish_page(
        "Expired page",
        slug: "expired-page",
        status: "published",
        publish_at: 2.hours.ago,
        unpublish_at: 1.hour.ago,
        time_zone: "UTC"
      )

      assert_equal "draft", draft.publishable_public_read[:status]
      assert_nil draft.publishable_public_read[:public_path]
      assert_nil draft.publishable_public_read[:public_url]

      assert_equal "scheduled", future.publishable_public_read[:status]
      assert_nil future.publishable_public_read[:public_path]
      assert_nil future.publishable_public_read[:public_url]

      assert_equal "published", expired.publishable_public_read[:status]
      assert_nil expired.publishable_public_read[:public_path]
      assert_nil expired.publishable_public_read[:public_url]

      with_trashed_kept_filter do
        trashed_parent = publish_page("Trashed parent", slug: "trashed-parent", status: "published")
        parent_child = trashed_parent.publishable_child_recording
        parent_publishable = trashed_parent.current_publishable
        RecordingStudio::Recording.where(id: trashed_parent.id).update_all(trashed_at: Time.current)

        parent_read = RecordingStudioPublishable::PublicRead.for(
          trashed_parent.reload,
          publishable: parent_publishable,
          publishable_recording: parent_child
        )
        assert_equal "published", parent_read[:status]
        assert_nil parent_read[:public_path]
        assert_nil parent_read[:public_url]

        trashed_child = publish_page("Trashed child", slug: "trashed-child", status: "published")
        child = trashed_child.publishable_child_recording
        publishable = trashed_child.current_publishable
        RecordingStudio::Recording.where(id: child.id).update_all(trashed_at: Time.current)

        child_read = RecordingStudioPublishable::PublicRead.for(
          trashed_child.reload,
          publishable: publishable,
          publishable_recording: child
        )
        assert_nil child_read[:public_path]
        assert_nil child_read[:public_url]
        assert_nil trashed_child.publishable_public_read[:public_path]
      end
    end

    test "publish_at at now returns a link and unpublish_at at now does not" do
      Rails.application.routes.default_url_options = { host: "press.test", protocol: "https" }
      freeze_time do
        now = Time.current.change(usec: 0)
        travel_to now
        recording = publish_page("Boundary page", slug: "boundary-page", status: "published", publish_at: now)
        child = recording.publishable_child_recording

        assert_equal now.to_i, recording.current_publishable.publish_at.to_i
        assert_equal "/published/#{child.id}/boundary-page", recording.publishable_public_read[:public_path]
        assert_equal "https://press.test/published/#{child.id}/boundary-page",
                     recording.publishable_public_read[:public_url]

        publish_page_on(
          recording,
          slug: "boundary-page",
          status: "published",
          publish_at: 1.hour.ago,
          unpublish_at: now,
          time_zone: "UTC"
        )
        recording.reload

        assert_equal now.to_i, recording.current_publishable.unpublish_at.to_i
        assert_nil recording.publishable_public_read[:public_path]
        assert_nil recording.publishable_public_read[:public_url]
      end
    end

    private

    def publish_page(title, **attributes)
      recording = RecordingStudio::Recording.create!(
        recordable: Page.create!(title: title),
        parent_recording: @root
      )
      publish_page_on(recording, **attributes)
      recording.reload
    end

    def publish_page_on(recording, **attributes)
      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: recording,
        attributes: attributes
      ).value!
    end

    def with_trashed_kept_filter
      RecordingStudio.register_recording_filter(
        :trashed,
        sql: ->(table) { "#{table}.trashed_at IS NULL" }
      ) { |recordings| recordings.where(trashed_at: nil) }
      yield
    ensure
      RecordingStudio.unregister_recording_filter(:trashed)
    end
  end
end
