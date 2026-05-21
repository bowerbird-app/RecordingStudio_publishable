# frozen_string_literal: true

module RecordingStudioPublishable
  class EditButtonComponent < ViewComponent::Base
    BUTTON_BASE_CLASS = "inline-flex items-center justify-center rounded-[var(--button-border-radius)] border px-[var(--button-padding-x-md)] py-[var(--button-padding-y-md)] text-sm font-medium leading-none transition-opacity duration-base hover:opacity-90"

    def initialize(recording: nil, publishable: nil, label: "Edit", show_tooltip: false, **options)
      @recording = recording || recording_for_publishable(publishable)
      @label = label
      @show_tooltip = show_tooltip
      @options = options
    end

    def call
      raise ArgumentError, "recording is required for EditButtonComponent" unless @recording

      button = link_to edit_path, class: button_class, **@options do
        concat(tag.span(button_text))
      end

      return button unless @show_tooltip

      tooltip_text = tooltip_copy
      return button if tooltip_text.blank?

      helpers.render(FlatPack::Tooltip::Component.new(text: tooltip_text, placement: :top)) do
        button
      end
    end

    private

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
      helpers.recording_studio_publishable.edit_recording_publishable_path(recording_id: @recording.id)
    end

    def tooltip_copy
      publishable = @recording.current_publishable
      return if publishable.blank? || !publishable.published_state?

      if publishable.scheduled_for_future?
        return "Scheduled to publish in #{helpers.distance_of_time_in_words(Time.current, publishable.publish_at)}"
      end

      publish_at = publishable.publish_at
      return "Published just now" if publish_at.blank?

      "Published #{helpers.time_ago_in_words(publish_at)} ago"
    end

    def recording_for_publishable(publishable)
      return unless publishable

      normalize_recording(
        publishable.try(:recording) ||
        publishable.try(:publishable_recording) ||
        publishable.try(:parent_recording)
      )
    end

    def normalize_recording(recording)
      return unless recording
      return recording unless recording.respond_to?(:recordable_type)
      return recording unless recording.recordable_type == RecordingStudioPublishable::Publishable.name

      recording.parent_recording || recording
    end
  end
end
