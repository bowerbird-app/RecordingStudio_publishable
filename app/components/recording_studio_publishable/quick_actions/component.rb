# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    class Component < ViewComponent::Base
      CLOSED_STATES = {
        draft: {
          trigger: "Draft",
          style: :secondary,
          icon: "document-text",
          actions: %i[publish]
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
          actions: %i[draft]
        }
      }.freeze

      ACTIONS = {
        publish: { text: "Publish now", icon: "globe-alt", transition: :publish },
        draft: { text: "Back to draft", icon: "pencil-square", transition: :draft }
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

      def transition_url(transition)
        helpers.recording_studio_publishable.transition_recording_publishable_path(
          recording_id: recording.id,
          transition: transition,
          inline: 1
        )
      end

      def edit_url
        helpers.recording_studio_publishable.edit_recording_publishable_path(recording_id: recording.id)
      end
    end
  end
end
