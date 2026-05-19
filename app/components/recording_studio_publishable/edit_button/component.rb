# frozen_string_literal: true

module RecordingStudioPublishable
  module EditButton
    class Component < ViewComponent::Base
      BUTTON_BASE_CLASS = "inline-flex items-center justify-center rounded-[var(--button-border-radius)] border px-[var(--button-padding-x-md)] py-[var(--button-padding-y-md)] text-sm font-medium leading-none transition-opacity duration-base hover:opacity-90"

      def initialize(recording: nil, publishable: nil, label: "Edit", **options)
        @recording = recording || recording_for_publishable(publishable)
        @label = label
        @options = options
      end

      def button_class
        [BUTTON_BASE_CLASS, button_tone_class].join(" ")
      end

      def button_tone_class
        case button_tone
        when :primary
          "border-[var(--button-primary-border-color)] bg-[var(--button-primary-background-color)] text-[var(--button-primary-text-color)]"
        when :warning
          "border-[var(--button-warning-border-color)] bg-[var(--button-warning-background-color)] text-[var(--button-warning-text-color)]"
        when :default
          "border-[var(--button-default-border-color)] bg-[var(--button-default-background-color)] text-[var(--button-default-text-color)]"
        else
          "border-[var(--button-secondary-border-color)] bg-[var(--button-secondary-background-color)] text-[var(--button-secondary-text-color)]"
        end
      end

      def button_tone
        publishable = @recording.current_publishable
        return :secondary unless publishable.present?
        return :primary if publishable.published_state?

        :secondary
      end

      def button_text
        publishable = @recording.current_publishable
        return @label unless publishable.present?

        publishable.published_state? ? "Published" : "Draft"
      end

      def edit_path
        raise ArgumentError, "recording is required for EditButton" unless @recording

        helpers.recording_studio_publishable.edit_recording_publishable_path(recording_id: @recording.id)
      end

      private

      def recording_for_publishable(publishable)
        return unless publishable

        publishable.try(:recording) ||
          publishable.try(:publishable_recording) ||
          publishable.try(:parent_recording)
      end
    end
  end
end
