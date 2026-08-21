# frozen_string_literal: true

module RecordingStudioPublishable
  class Publishable < ApplicationRecord
    include RecordingStudio::Capabilities::Attachable.to(
      allowed_content_types: ["image/*"],
      enabled_attachment_kinds: %i[image],
      max_file_count: 10
    )

    self.table_name = "recording_studio_publishable_publishables"

    if respond_to?(:recording_studio_recordable)
      recording_studio_recordable(
        label: "Publishable",
        plural_label: "Publishables",
        root: false
      )
    end

    belongs_to :social_image_attachment_recording,
               class_name: "RecordingStudio::Recording",
               optional: true

    enum :status, {
      draft: "draft",
      published: "published"
    }, default: :draft, validate: true

    validates :slug, presence: true
    validates :slug,
              format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must use URL-safe lowercase slug segments" }
    validates :seo_description, length: { maximum: 160 }, allow_blank: true
    validates :social_description, length: { maximum: 200 }, allow_blank: true
    validate :publish_window_is_valid

    scope :currently_published, lambda {
      now = Time.current
      where(status: statuses[:published])
        .where("publish_at IS NULL OR publish_at <= ?", now)
        .where("unpublish_at IS NULL OR unpublish_at > ?", now)
    }
    scope :scheduled, lambda {
      now = Time.current
      where(status: statuses[:published]).where("publish_at > ?", now)
    }
    scope :draft, -> { where(status: statuses[:draft]) }
    scope :unpublished, -> { where(status: statuses[:draft]).where.not(unpublish_at: nil) }

    def published_state?
      status == self.class.statuses[:published]
    end

    def draft_state?
      status == self.class.statuses[:draft]
    end

    def currently_published?(now = Time.current)
      published_state? && (publish_at.blank? || publish_at <= now) && (unpublish_at.blank? || unpublish_at > now)
    end

    def published?(now = Time.current)
      currently_published?(now)
    end

    def scheduled_for_future?(now = Time.current)
      published_state? && publish_at.present? && publish_at > now
    end

    def previously_published?(now = Time.current)
      return false if currently_published?(now)

      unpublish_at.present? && unpublish_at <= now
    end

    def unpublished?(now = Time.current)
      draft_state? && !currently_published?(now) && previously_published?(now)
    end

    def effective_time_zone
      time_zone.presence || RecordingStudioPublishable.configuration.default_time_zone || "UTC"
    end

    def social_image_supported?
      self.class.connection.data_source_exists?("recording_studio_attachable_attachments") &&
        self.class.connection.data_source_exists?("recording_studio_recordings") &&
        self.class.column_names.include?("social_image_attachment_recording_id") &&
        self.class.connection.data_source_exists?("active_storage_attachments") &&
        self.class.connection.data_source_exists?("active_storage_blobs")
    rescue ActiveRecord::ActiveRecordError, ActiveRecord::NoDatabaseError
      false
    end

    def social_image_attachment
      social_image_attachment_recording&.recordable
    end

    def social_image_attached?
      social_image_attachment_recording.present?
    end

    private

    def publish_window_is_valid
      return unless published_state?
      return if publish_at.blank? || unpublish_at.blank? || publish_at < unpublish_at

      errors.add(:unpublish_at, "must be later than publish at")
    end
  end
end
