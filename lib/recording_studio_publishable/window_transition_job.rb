# frozen_string_literal: true

require "active_job"

module RecordingStudioPublishable
  # Fires when a stored publish/unpublish window is due.
  #
  # Public visibility is a time-based read of status + publish_at + unpublish_at.
  # Nothing writes when a scheduled page goes live or expires, so this job is the
  # write-adjacent signal: it re-reads the parent and emits the same after-commit
  # events a manual publish/unpublish would.
  class WindowTransitionJob < ActiveJob::Base
    queue_as :default

    def perform(parent_recording_id, transition, expected_at)
      LifecycleNotifications.emit_scheduled!(
        parent_recording_id: parent_recording_id,
        transition: transition,
        expected_at: expected_at
      )
    end
  end
end
