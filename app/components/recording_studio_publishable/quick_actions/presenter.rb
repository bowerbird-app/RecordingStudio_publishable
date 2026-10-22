# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # State, label, icon, and the rows both renderers share.
    class Presenter
      NAME_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

      def self.wrapper_id(recording, name: nil)
        base = "publishable_quick_actions_#{recording.id}"
        suffix = normalize_name(name)
        suffix.present? ? "#{base}_#{suffix}" : base
      end

      def self.normalize_name(name)
        return if name.blank?

        value = name.to_s
        return value if value.match?(NAME_PATTERN)

        raise ArgumentError, "Invalid quick actions name: #{name}"
      end

      def self.name_from_param(raw)
        normalize_name(raw)
      rescue ArgumentError
        nil
      end

      def initialize(recording:, routes:, **display)
        @recording = recording
        @routes = routes
        @size = display.fetch(:size)
        @alert = display[:alert]
        @appearance = display.fetch(:appearance)
        @name = display[:name]
        @renderer = display.fetch(:renderer)
      end

      attr_reader :recording, :size, :alert, :appearance, :name, :renderer, :routes

      def wrapper_id = self.class.wrapper_id(recording, name: name)
      def alert_id = "#{wrapper_id}_alert"
      def state_id = "#{wrapper_id}_state"
      def menu_frame_id = "#{wrapper_id}_menu"
      def menu_body_id = "#{wrapper_id}_menu_items"
      def list_body_id = "#{wrapper_id}_list"

      def closed_state
        publishable = recording.current_publishable
        return :draft if publishable.blank? || !publishable.published_state?

        publishable.scheduled_for_future? ? :scheduled : :published
      end

      def trigger_text
        closed_state == :scheduled ? scheduled_trigger_text : Copy.t("status.#{closed_state}")
      end

      def state
        appearance.state_config(closed_state)
      end

      def style = state[:style]
      def icon = state[:icon]
      def icon_variant = state[:icon_variant]
      def icon_style = state[:icon_style]

      def press
        FlatPack::Button::StyleRegistry.press_for(style).to_s
      end

      def rows
        MenuRows.new(self).to_a
      end

      def form_params
        {
          inline: 1,
          button_size: size,
          quick_actions_name: name,
          quick_actions_renderer: renderer
        }.merge(appearance.transition_style_params).compact
      end

      def schedule_enabled?
        RecordingStudioPublishable.configuration.schedule_enabled_for(recording.recordable_type)
      end

      private

      def scheduled_trigger_text
        publishable = recording.current_publishable
        return Copy.t("status.scheduled") if publishable&.publish_at.blank?

        time = publishable.publish_at.in_time_zone(publishable.effective_time_zone)
        "#{Copy.l(time, format: '%b')} #{time.day}"
      end

      def transition_path(transition)
        publishable_routes.transition_recording_publishable_path(
          recording_id: recording.id,
          transition: transition
        )
      end

      def job_path(key)
        publishable_routes.public_send("#{key}_recording_publishable_path", recording_id: recording.id)
      end

      def publishable_routes
        routes.recording_studio_publishable
      end
    end
  end
end
