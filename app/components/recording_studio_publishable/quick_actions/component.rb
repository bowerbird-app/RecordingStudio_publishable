# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    class Component < ViewComponent::Base
      CLOSED_STATES = {
        draft: {
          trigger: "Draft",
          style: :secondary,
          icon: "pencil-square",
          actions: %i[publish schedule]
        },
        scheduled: {
          trigger: "Scheduled",
          style: :default,
          icon: "clock",
          actions: %i[publish schedule unpublish]
        },
        published: {
          trigger: "Published",
          style: :success,
          icon: "check-circle",
          actions: %i[unpublish schedule]
        }
      }.freeze

      ACTIONS = {
        publish: { text: "Publish now", icon: "rocket-launch", transition: :publish },
        schedule: { text: "Schedule", icon: "clock" },
        unpublish: { text: "Unpublish", icon: "pencil-square", transition: :draft }
      }.freeze

      BUTTON_SIZES = %i[sm md lg].freeze

      def initialize(recording:, size: :md, alert: nil)
        @recording = recording
        @size = self.class.normalize_size(size)
        @alert = alert
      end

      attr_reader :recording, :size, :alert

      def self.normalize_size(value)
        size = value.to_s.to_sym
        BUTTON_SIZES.include?(size) ? size : :md
      end

      def self.wrapper_id(recording)
        "publishable_quick_actions_#{recording.id}"
      end

      def wrapper_id
        self.class.wrapper_id(recording)
      end

      def closed_state
        publishable = recording.current_publishable
        return :draft if publishable.blank?
        return :scheduled if publishable.scheduled_for_future?
        return :published if publishable.published_state?

        :draft
      end

      def state_config
        CLOSED_STATES.fetch(closed_state)
      end

      def trigger_text
        return scheduled_trigger_text if closed_state == :scheduled

        state_config[:trigger]
      end

      def action_config(action_name)
        config = ACTIONS.fetch(action_name)
        return config unless action_name == :schedule && closed_state == :scheduled

        config.merge(text: "Change schedule")
      end

      def menu_actions
        names = state_config[:actions]
        return names if schedule_enabled?

        names - [:schedule]
      end

      def action_href(action)
        return transition_url(action[:transition]) if action[:transition]

        schedule_url
      end

      def action_data(action)
        return { turbo_method: :patch, turbo_stream: true } if action[:transition]

        {}
      end

      def schedule_enabled?
        RecordingStudioPublishable.configuration.schedule_enabled_for(recording.recordable_type)
      end

      def transition_url(transition)
        helpers.recording_studio_publishable.transition_recording_publishable_path(
          recording_id: recording.id,
          transition: transition,
          inline: 1,
          button_size: size
        )
      end

      def schedule_url
        helpers.recording_studio_publishable.schedule_recording_publishable_path(
          recording_id: recording.id
        )
      end

      def edit_url
        helpers.recording_studio_publishable.edit_recording_publishable_path(
          recording_id: recording.id
        )
      end

      private

      def scheduled_trigger_text
        publishable = recording.current_publishable
        publish_at = publishable&.publish_at
        return "Scheduled" if publish_at.blank?

        time = publish_at.in_time_zone(publishable.effective_time_zone)
        "#{time.strftime('%b')} #{time.day}"
      end
    end
  end
end
