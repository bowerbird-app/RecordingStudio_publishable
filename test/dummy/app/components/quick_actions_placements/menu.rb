# frozen_string_literal: true

module QuickActionsPlacements
  # FlatPack menu slots are a link or a bare button. Publish rows are forms.
  # menu_html places that rendered list in the menu as given.
  class Menu < FlatPack::Button::Dropdown::Component
    def initialize(menu_html:, **)
      body = menu_html
      super(**)
      menu_html(body)
    end
  end
end
