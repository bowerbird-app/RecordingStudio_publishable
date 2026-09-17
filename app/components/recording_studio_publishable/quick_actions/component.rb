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
          style: :warning,
          icon: "clock",
          actions: %i[publish draft]
        },
        published: {
          trigger: "Published",
          style: :success,
          icon: "check-circle",
          actions: %i[unpublish]
        }
      }.freeze

      ACTIONS = {
        publish: { text: "Publish now", icon: "rocket-launch", transition: :publish },
        schedule: { text: "Schedule", icon: "clock" },
        draft: { text: "Back to draft", icon: "pencil-square", transition: :draft },
        unpublish: { text: "Unpublish", icon: "pencil-square", transition: :draft }
      }.freeze

      def initialize(recording:, size: :md, notice: nil, alert: nil)
        @recording = recording
        @size = size
        @notice = notice
        @alert = alert
      end

      attr_reader :recording, :size, :notice, :alert

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

      def action_config(action_name)
        ACTIONS.fetch(action_name)
      end

      def menu_actions
        names = state_config[:actions]
        return names if schedule_enabled?

        names - [:schedule]
      end

      def action_href(action)
        return transition_url(action[:transition]) if action[:transition]

        edit_url(schedule: 1)
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
          inline: 1
        )
      end

      def edit_url(**query)
        helpers.recording_studio_publishable.edit_recording_publishable_path(
          recording_id: recording.id,
          **query
        )
      end
    end
  end
end
