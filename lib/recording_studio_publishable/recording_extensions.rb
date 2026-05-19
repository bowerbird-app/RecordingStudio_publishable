# frozen_string_literal: true

require "active_support/concern"

module RecordingStudioPublishable
  module RecordingExtensions
    extend ActiveSupport::Concern

    included do
      scope :with_publishable_child, lambda {
        joins(<<~SQL.squish)
          INNER JOIN recording_studio_recordings publishable_recordings
            ON publishable_recordings.parent_recording_id = recording_studio_recordings.id
           AND publishable_recordings.recordable_type = 'RecordingStudioPublishable::Publishable'
           AND publishable_recordings.trashed_at IS NULL
          INNER JOIN recording_studio_publishable_publishables
            ON recording_studio_publishable_publishables.id = publishable_recordings.recordable_id
        SQL
      }

      scope :currently_published, -> { with_publishable_child.merge(RecordingStudioPublishable::Publishable.currently_published).distinct }
      scope :scheduled_publishables, -> { with_publishable_child.merge(RecordingStudioPublishable::Publishable.scheduled).distinct }
      scope :draft_publishables, -> { with_publishable_child.merge(RecordingStudioPublishable::Publishable.draft).distinct }
      scope :unpublished_publishables, -> { with_publishable_child.merge(RecordingStudioPublishable::Publishable.unpublished).distinct }
    end

    def publishable_child_recording
      child_recordings
        .where(recordable_type: RecordingStudioPublishable::Publishable.name, trashed_at: nil)
        .order(created_at: :desc, id: :desc)
        .first
    end

    def current_publishable
      publishable_child_recording&.recordable
    end

    def currently_published?
      current_publishable&.currently_published? || false
    end

    def publishable_public_path
      return unless publishable_child_recording && current_publishable

      RecordingStudioPublishable::Routing.path_for(
        publishable_recording: publishable_child_recording,
        publishable: current_publishable,
        parent_recordable_type: recordable_type
      )
    end

    def publishable_public_url(host: nil, protocol: nil)
      return unless publishable_child_recording && current_publishable

      RecordingStudioPublishable::Routing.url_for(
        publishable_recording: publishable_child_recording,
        publishable: current_publishable,
        parent_recordable_type: recordable_type,
        host: host,
        protocol: protocol
      )
    end
  end
end
