# frozen_string_literal: true

require "active_support/concern"

module RecordingStudioPublishable
  module RecordingExtensions
    def publishable_child_recording
      return @publishable_child_recording if instance_variable_defined?(:@publishable_child_recording)

      relation = child_recordings.of_type(RecordingStudioPublishable::Publishable)
      if RecordingStudioPublishable::TrashedAt.column? && relation.respond_to?(:where)
        relation = relation.where(trashed_at: nil)
      end

      @publishable_child_recording = relation.first
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
