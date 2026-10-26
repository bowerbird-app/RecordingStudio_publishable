# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # FlatPack moves the open menu onto document.body, so a class on an
    # ancestor does not travel with it. Host classes are applied to the menu
    # element itself, along with a stable hook class.
    #
    # Publish replaces the label and the rows. The trigger and menu elements stay.
    class DropdownComponent < FlatPack::Button::Dropdown::Component
      MENU_HOOK_CLASS = "publishable-quick-actions-menu"

      def initialize(button_class: nil, menu_class: nil, state_presenter: nil, trigger_attributes: {}, **)
        @menu_class = menu_class
        @state_presenter = state_presenter
        super(trigger_attributes: trigger_attributes_with_button_class(trigger_attributes, button_class), **)
      end

      attr_reader :state_presenter

      private

      # The trigger stays a raw button so the state span can be replaced in place.
      # Flatpack 0.1.319 paints that button through Button and removed
      # Dropdown#button_attributes. Flatpack 0.1.315 still has that method.
      def button_attributes
        if respond_to?(:trigger_button_arguments, true)
          FlatPack::Button::Component.new(**trigger_button_arguments).send(:button_attributes)
        else
          super
        end
      end

      def trigger_attributes_with_button_class(trigger_attributes, button_class)
        attributes = trigger_attributes.dup
        return attributes if button_class.blank?

        attributes[:class] = ClassNames.merge(attributes[:class], attributes["class"], button_class)
        attributes.delete("class")
        attributes
      end

      def menu_classes
        ClassNames.merge(super, MENU_HOOK_CLASS, @menu_class)
      end

      def dropdown_data_attributes
        data = super
        data.merge(controller: "publishable-quick-actions #{data[:controller]}")
      end

      def menu_attributes
        attributes = super
        return attributes if state_presenter.blank?

        attributes.merge(id: state_presenter.menu_frame_id)
      end
    end
  end
end
