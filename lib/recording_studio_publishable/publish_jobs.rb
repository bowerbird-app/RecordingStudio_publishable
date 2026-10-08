# frozen_string_literal: true

module RecordingStudioPublishable
  class PublishJobs
    Job = Data.define(:key, :icon, :attributes, :capability) do
      def title
        Copy.t("jobs.#{key}.title")
      end

      def subtitle
        Copy.t("jobs.#{key}.subtitle")
      end

      def notice
        Copy.t("jobs.#{key}.notice")
      end
    end

    TABLE = {
      schedule: Job.new(
        key: :schedule,
        icon: "clock",
        attributes: %i[publish_at unpublish_at time_zone].freeze,
        capability: :schedule
      ),
      search: Job.new(
        key: :search,
        icon: "magnifying-glass",
        attributes: %i[slug canonical_url meta_robots seo_title seo_description].freeze,
        capability: nil
      ),
      social: Job.new(
        key: :social,
        icon: "share",
        attributes: %i[social_title social_description social_image_attachment_recording_id].freeze,
        capability: nil
      )
    }.freeze

    class << self
      def fetch(key)
        return if key.blank?

        TABLE[key.to_s.to_sym]
      end

      def listed(schedule_enabled:)
        TABLE.each_value.select { |job| enabled?(job, schedule_enabled: schedule_enabled) }
      end

      def enabled?(job, schedule_enabled:)
        job.capability.nil? || (job.capability == :schedule && schedule_enabled)
      end

      def path_method(job)
        :"#{job.key}_recording_publishable_path"
      end
    end
  end
end
