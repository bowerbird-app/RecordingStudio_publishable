# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # Menu rows shared by the dropdown and the flat list.
    # Publish and unpublish are real forms so a surrounding menu stays open.
    class RowsComponent < ViewComponent::Base
      def initialize(presenter:)
        @presenter = presenter
      end

      attr_reader :presenter

      ITEM_CLASSES = [
        "flex items-center gap-[var(--dropdown-item-gap)]",
        "w-full",
        "px-[var(--dropdown-item-padding-x)] py-[var(--dropdown-item-padding-y)]",
        "text-sm text-left",
        "rounded-[var(--dropdown-item-radius)]",
        "text-[var(--surface-content-color)]",
        "hover:bg-[var(--surface-muted-background-color)]",
        "cursor-pointer",
        "transition-colors duration-base",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring"
      ].join(" ").freeze

      def icon_for(row)
        return if row.icon.blank?

        render(FlatPack::Shared::IconComponent.new(**icon_arguments(row.icon)))
      end

      def item_classes
        ITEM_CLASSES
      end

      def icon_arguments(name)
        FlatPack::Button::IconOptions.component_arguments(
          name: name,
          size: :sm,
          icon_variant: nil,
          icon_style: nil
        )
      end

      def link_options(row)
        options = { class: item_classes, role: "menuitem" }
        options[:target] = row.target if row.target.present?
        options[:rel] = row.rel if row.rel.present?
        options[:data] = row.data if row.data.present?
        options
      end
    end
  end
end
