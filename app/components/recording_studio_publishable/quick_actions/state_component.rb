# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # The label inside the trigger. Replaced on its own so the trigger node stays.
    class StateComponent < ViewComponent::Base
      def initialize(presenter:)
        @presenter = presenter
      end

      def call
        tag.span(
          safe_join([icon, label].compact),
          id: @presenter.state_id,
          class: "inline-flex items-center gap-2",
          data: span_data
        )
      end

      private

      def span_data
        {
          publishable_quick_actions_target: "state",
          style: @presenter.style.to_s,
          press: @presenter.press
        }
      end

      def label
        return if @presenter.trigger_text.blank?

        tag.span(@presenter.trigger_text)
      end

      def icon
        return if @presenter.icon.blank?

        render(FlatPack::Shared::IconComponent.new(**icon_arguments))
      end

      def icon_arguments
        FlatPack::Button::IconOptions.component_arguments(
          name: @presenter.icon,
          size: FlatPack::Button::Component.painted_icon_size(@presenter.size),
          icon_variant: @presenter.icon_variant,
          icon_style: @presenter.icon_style
        )
      end
    end
  end
end
