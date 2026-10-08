# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    class Component < ViewComponent::Base
      CLOSED_STATES = {
        draft: {
          style: :secondary,
          icon: "pencil-square",
          actions: %i[publish schedule]
        },
        scheduled: {
          style: :default,
          icon: "clock",
          actions: %i[publish schedule unpublish]
        },
        published: {
          style: :success,
          icon: "check-circle",
          actions: %i[unpublish schedule]
        }
      }.freeze

      ACTIONS = {
        publish: { icon: "rocket-launch", transition: :publish, text_key: "actions.publish_now" },
        schedule: { icon: "clock", text_key: "actions.schedule" },
        unpublish: { icon: "pencil-square", transition: :draft, text_key: "actions.unpublish" }
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

      def wrapper_id = self.class.wrapper_id(recording)

      def closed_state
        publishable = recording.current_publishable
        return :draft if publishable.blank? || !publishable.published_state?

        publishable.scheduled_for_future? ? :scheduled : :published
      end

      def state_config
        CLOSED_STATES.fetch(closed_state)
      end

      def trigger_text
        closed_state == :scheduled ? scheduled_trigger_text : Copy.t("status.#{closed_state}")
      end

      def action_config(action_name)
        config = ACTIONS.fetch(action_name)
        key = change_schedule?(action_name) ? "actions.change_schedule" : config[:text_key]
        config.merge(text: Copy.t(key))
      end

      def menu_actions
        schedule_enabled? ? state_config[:actions] : state_config[:actions] - [:schedule]
      end

      def action_href(action)
        return transition_url(action[:transition]) if action[:transition]

        job_url(:schedule)
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

      def job_url(key)
        helpers.recording_studio_publishable.public_send(
          "#{key}_recording_publishable_path",
          recording_id: recording.id
        )
      end

      def page_link
        RecordingStudioPublishable::PageLink.for(
          recording: recording,
          preview_href: job_url(:preview)
        ).to_h
      end

      def job_action_text(key)
        Copy.t("actions.#{key}")
      end

      private

      def change_schedule?(action_name)
        action_name == :schedule && closed_state == :scheduled
      end

      def scheduled_trigger_text
        publishable = recording.current_publishable
        return Copy.t("status.scheduled") if publishable&.publish_at.blank?

        time = publishable.publish_at.in_time_zone(publishable.effective_time_zone)
        "#{Copy.l(time, format: '%b')} #{time.day}"
      end
    end
  end
end
