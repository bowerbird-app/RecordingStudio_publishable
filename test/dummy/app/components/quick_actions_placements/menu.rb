# frozen_string_literal: true

module QuickActionsPlacements
  # FlatPack dropdown slots are a link or a bare button. A form cannot go
  # through them. This is that same dropdown, with room in the menu for the
  # flat list.
  class Menu < FlatPack::Button::Dropdown::Component
    def initialize(menu_html:, **)
      @menu_html = menu_html
      super(**)
    end

    def call
      content_tag(:div, **wrapper_attributes) do
        safe_join([
          content_tag(:button, button_content, **trigger_attributes),
          content_tag(:div, @menu_html, **menu_attributes)
        ])
      end
    end

    private

    def trigger_attributes
      attributes = button_attributes
      attributes[:type] = "button"
      attributes[:disabled] = true if @disabled
      attributes
    end
  end
end
