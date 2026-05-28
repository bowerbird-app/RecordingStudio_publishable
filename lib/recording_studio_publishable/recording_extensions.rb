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

      scope :published, -> { currently_published }
      scope :scheduled, -> { scheduled_publishables }
      scope :draft, -> { draft_publishables }
      scope :unpublished, -> { unpublished_publishables }

      scope :scheduled_in, lambda { |at_or_before|
        next none if at_or_before.blank?

        if at_or_before.is_a?(Range)
          scheduled_between(at_or_before)
        else
          scheduled_between(Time.current..at_or_before)
        end
      }

      scope :scheduled_between, lambda { |publish_window|
        next none unless publish_window.is_a?(Range)

        scheduled.where(recording_studio_publishable_publishables: { publish_at: publish_window })
      }
    end

    def publishable_child_recording
      return @publishable_child_recording if instance_variable_defined?(:@publishable_child_recording)

      @publishable_child_recording = child_recordings.of_type(RecordingStudioPublishable::Publishable).first
    end

    def current_publishable
      return @current_publishable if instance_variable_defined?(:@current_publishable)

      @current_publishable = publishable_child_recording&.recordable
    end

    def currently_published?
      current_publishable&.currently_published? || false
    end

    def published?
      current_publishable&.published? || false
    end

    def draft?
      current_publishable&.draft_state? || false
    end

    def scheduled?
      current_publishable&.scheduled_for_future? || false
    end

    def published_state?
      current_publishable&.published_state? || false
    end

    def draft_state?
      current_publishable&.draft_state? || false
    end

    def scheduled_for_future?
      current_publishable&.scheduled_for_future? || false
    end

    def previously_published?
      current_publishable&.previously_published? || false
    end

    def unpublished?
      current_publishable&.unpublished? || false
    end

    def social_image_supported?
      current_publishable&.social_image_supported? || false
    end

    def social_image_attached?
      current_publishable&.social_image_attached? || false
    end

    def publishable_public_path
      return unless respond_to?(:recordable) && recordable.respond_to?(:published_url)

      recordable.published_url
    end

    def publishable_public_url(host: nil, protocol: nil)
      path = publishable_public_path
      return if path.blank?

      return path if host.blank?

      effective_protocol = protocol.presence || "https"
      "#{effective_protocol}://#{host}#{path}"
    end
  end
end
