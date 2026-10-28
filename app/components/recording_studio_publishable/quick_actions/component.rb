# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    class Component < ViewComponent::Base
      BUTTON_SIZES = %i[sm md lg].freeze

      def initialize(recording:, size: :md, alert: nil, name: nil, **options)
        super()
        @recording = recording
        @size = self.class.normalize_size(size)
        @alert = alert
        @name = self.class.normalize_name(name)
        @appearance = Appearance.from(options)
      end

      attr_reader :recording, :size, :alert, :appearance, :name

      def self.normalize_size(value)
        size = value.to_s.to_sym
        BUTTON_SIZES.include?(size) ? size : :md
      end

      def self.normalize_name(name)
        Presenter.normalize_name(name)
      end

      def self.wrapper_id(recording, name: nil)
        Presenter.wrapper_id(recording, name: name)
      end

      def presenter
        @presenter ||= Presenter.new(
          recording: recording,
          size: size,
          alert: alert,
          appearance: appearance,
          name: name,
          renderer: renderer_name,
          routes: helpers
        )
      end

      def renderer_name
        "dropdown"
      end

      def dropdown
        DropdownComponent.new(**dropdown_content, **dropdown_chrome)
      end

      def dropdown_content
        state = presenter.state
        {
          text: presenter.trigger_text,
          style: state[:style],
          size: size,
          icon: state[:icon],
          icon_variant: state[:icon_variant],
          icon_style: state[:icon_style]
        }
      end

      def dropdown_chrome
        {
          placement: (size.to_sym == :sm ? :bottom_left : :bottom_right),
          button_class: appearance.button_class,
          menu_class: appearance.menu_class,
          trigger_attributes: appearance.html_attributes,
          state_presenter: presenter
        }
      end
    end
  end
end
