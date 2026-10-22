# frozen_string_literal: true

module QuickActionsPlacements
  # FlatPack's phone-menu source. The bar does not show it. On a phone the
  # top nav moves this node into the hamburger panel.
  class PhoneMenu < ViewComponent::Base
    def initialize(recording:)
      @recording = recording
    end

    def call
      content_tag(
        :div,
        render(RecordingStudioPublishable::QuickActions::ListComponent.new(recording: @recording, name: "phone")),
        class: "fp-page-nav-menu",
        data: {
          "flat-pack--top-nav-target": "section",
          "flat-pack-top-nav-collapsible": "true"
        }
      )
    end
  end
end
