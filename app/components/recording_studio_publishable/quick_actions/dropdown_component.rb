# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # FlatPack moves the open menu onto document.body, so a class on an
    # ancestor does not travel with it. Host classes are applied to the menu
    # element itself, along with a stable hook class.
    #
    # The trigger and menu elements stay in the document. Publish replaces the
    # label and the rows inside them, so a phone menu that already wired those
    # nodes keeps the same elements.
    class DropdownComponent < FlatPack::Button::Dropdown::Component
      MENU_HOOK_CLASS = "publishable-quick-actions-menu"

      def initialize(button_class: nil, menu_class: nil, state_presenter: nil, **)
        @button_class = button_class
        @menu_class = menu_class
        @state_presenter = state_presenter
        super(**)
      end

      attr_reader :state_presenter

      private

      def button_attributes
        attributes = super
        return attributes if @button_class.blank?

        attributes.merge(class: ClassNames.merge(attributes[:class], @button_class))
      end

      def menu_classes
        ClassNames.merge(super, MENU_HOOK_CLASS, @menu_class)
      end

      def dropdown_data_attributes
        data = super
        data.merge(
          controller: "publishable-quick-actions #{data[:controller]}",
          publishable_quick_actions_menu_id_value: state_presenter&.menu_frame_id
        )
      end

      def menu_attributes
        attributes = super
        return attributes if state_presenter.blank?

        attributes.merge(id: state_presenter.menu_frame_id)
      end
    end
  end
end
