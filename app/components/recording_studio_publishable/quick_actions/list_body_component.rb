# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    class ListBodyComponent < ViewComponent::Base
      def initialize(presenter:)
        @presenter = presenter
      end

      attr_reader :presenter

      def status_classes
        [
          "flex items-center gap-[var(--dropdown-item-gap)]",
          "w-full",
          "px-[var(--dropdown-item-padding-x)] py-[var(--dropdown-item-padding-y)]",
          "text-sm font-medium text-[var(--surface-content-color)]"
        ].join(" ")
      end

      def status_icon
        return if @presenter.icon.blank?

        render(FlatPack::Shared::IconComponent.new(**status_icon_arguments))
      end

      def status_icon_arguments
        FlatPack::Button::IconOptions.component_arguments(
          name: @presenter.icon,
          size: :sm,
          icon_variant: @presenter.icon_variant,
          icon_style: @presenter.icon_style
        )
      end
    end
  end
end
