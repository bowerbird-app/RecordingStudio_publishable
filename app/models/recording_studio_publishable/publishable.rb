# frozen_string_literal: true

module RecordingStudioPublishable
  class Publishable < ApplicationRecord
    self.table_name = "recording_studio_publishable_publishables"

    enum :status, {
      draft: "draft",
      scheduled: "scheduled",
      published: "published",
      unpublished: "unpublished"
    }, default: :draft, validate: true

    validates :slug, presence: true
    validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must use URL-safe lowercase slug segments" }
    validate :publish_window_is_valid
    validate :scheduled_status_requires_future_publish_at

    scope :currently_published, lambda {
      now = Time.current
      where(status: statuses[:published])
        .where("publish_at IS NULL OR publish_at <= ?", now)
        .where("unpublish_at IS NULL OR unpublish_at > ?", now)
    }
    scope :scheduled, lambda {
      now = Time.current
      where(status: statuses[:scheduled]).where("publish_at > ?", now)
    }
    scope :draft, -> { where(status: statuses[:draft]) }
    scope :unpublished, -> { where(status: statuses[:unpublished]) }

    def currently_published?(now = Time.current)
      published? && (publish_at.blank? || publish_at <= now) && (unpublish_at.blank? || unpublish_at > now)
    end

    def scheduled_for_future?(now = Time.current)
      scheduled? && publish_at.present? && publish_at > now
    end

    def previously_published?
      unpublished? || publish_at.present?
    end

    def effective_time_zone
      time_zone.presence || RecordingStudioPublishable.configuration.default_time_zone || "UTC"
    end

    private

    def publish_window_is_valid
      return if publish_at.blank? || unpublish_at.blank? || publish_at < unpublish_at

      errors.add(:unpublish_at, "must be later than publish at")
    end

    def scheduled_status_requires_future_publish_at
      return unless scheduled?
      return if publish_at.present? && publish_at.future?

      errors.add(:publish_at, "must be in the future when status is scheduled")
    end
  end
end
