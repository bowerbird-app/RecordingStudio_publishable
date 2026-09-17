# frozen_string_literal: true

module RecordingStudioPublishable
  class PublishJobs
    Job = Data.define(:key, :title, :subtitle, :icon, :attributes, :capability, :notice)

    TABLE = {
      schedule: Job.new(
        key: :schedule,
        title: "Schedule",
        subtitle: "Pick when this goes live.",
        icon: "clock",
        attributes: %i[publish_at unpublish_at time_zone].freeze,
        capability: :schedule,
        notice: "Times saved."
      ),
      search: Job.new(
        key: :search,
        title: "Search",
        subtitle: "How this shows up in search.",
        icon: "magnifying-glass",
        attributes: %i[slug canonical_url meta_robots seo_title seo_description].freeze,
        capability: nil,
        notice: "Search listing saved."
      ),
      social: Job.new(
        key: :social,
        title: "Social",
        subtitle: "How this looks when someone shares it.",
        icon: "share",
        attributes: %i[social_title social_description social_image_attachment_recording_id].freeze,
        capability: nil,
        notice: "Social preview saved."
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
