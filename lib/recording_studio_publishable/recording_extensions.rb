# frozen_string_literal: true

require "active_support/concern"
require "recording_studio_publishable/publish_rules"

module RecordingStudioPublishable
  module RecordingExtensions
    extend ActiveSupport::Concern

    included do
      scope :currently_published, lambda {
        kept.joins(RecordingStudioPublishable::PublishRules.recording_child_join_sql(self))
            .merge(RecordingStudioPublishable::Publishable.currently_published)
            .distinct
      }
    end

    def publishable_child_recording
      child_recordings.kept.of_type(RecordingStudioPublishable::Publishable).first
    end

    def current_publishable
      publishable_child_recording&.recordable
    end

    def currently_published?
      return false if id.blank?

      self.class.currently_published.exists?(id: id)
    end

    def published?
      currently_published?
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

    def indexable?
      return false unless recordable.respond_to?(:indexable?)

      parent = RecordingStudioPublishable::PublishRules.newest_kept_parent(recordable)
      parent&.id == id && recordable.indexable?
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
