# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    class Component < ViewComponent::Base
      BUTTON_SIZES = %i[sm md lg].freeze
      MENU_HOOK_CLASS = "publishable-quick-actions-menu"

      def initialize(recording:, size: :md, alert: nil, name: nil, **options)
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

      def dropdown_kwargs
        {
          text: presenter.trigger_text,
          style: presenter.style,
          size: size,
          placement: (size.to_sym == :sm ? :bottom_left : :bottom_right),
          menu_class: ClassNames.merge(MENU_HOOK_CLASS, appearance.menu_class),
          menu_attributes: { id: presenter.menu_frame_id },
          trigger_attributes: trigger_attributes
        }
      end

      def menu_body
        tag.div(
          render(RowsComponent.new(presenter: presenter)),
          id: presenter.menu_body_id,
          class: presenter.target_classes(:menu_items)
        )
      end

      private

      def trigger_attributes
        attributes = appearance.html_attributes.dup
        return attributes if appearance.button_class.blank?

        attributes[:class] = ClassNames.merge(attributes[:class], attributes["class"], appearance.button_class)
        attributes.delete("class")
        attributes
      end
    end
  end
end
