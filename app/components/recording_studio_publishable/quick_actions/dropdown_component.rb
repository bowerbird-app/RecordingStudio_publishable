# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # FlatPack moves the open menu onto document.body, so a class on an
    # ancestor does not travel with it. Host classes are applied to the menu
    # element itself, along with a stable hook class.
    class DropdownComponent < FlatPack::Button::Dropdown::Component
      MENU_HOOK_CLASS = "publishable-quick-actions-menu"

      def initialize(button_class: nil, menu_class: nil, **)
        @button_class = button_class
        @menu_class = menu_class
        super(**)
      end

      private

      def button_attributes
        attributes = super
        return attributes if @button_class.blank?

        attributes.merge(class: ClassNames.merge(attributes[:class], @button_class))
      end

      def menu_classes
        ClassNames.merge(super, MENU_HOOK_CLASS, @menu_class)
      end
    end
  end
end
