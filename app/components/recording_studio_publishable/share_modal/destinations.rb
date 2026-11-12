# frozen_string_literal: true

module RecordingStudioPublishable
  module ShareModal
    class Destinations < ViewComponent::Base
      def initialize(sheet:)
        super()
        @sheet = sheet
      end

      def call
        content_tag(:div, class: "mt-6 flex flex-col gap-2", aria: { label: Copy.t("share.destinations_label") }) do
          safe_join(@sheet.destinations.filter_map { |name| action_for(name) })
        end
      end

      private

      def action_for(name)
        return copy_button if name == :copy
        return native_button if name == :native

        link_button(name)
      end

      def copy_button
        content_tag(:div, class: "w-full [&>span]:w-full [&>span>button]:w-full") do
          render FlatPack::CopyButton::Component.new(
            text: @sheet.url,
            label: Copy.t("share.copy_link"),
            style: :primary,
            size: :md
          )
        end
      end

      def native_button
        content_tag(:div, hidden: true, class: "hidden w-full", data: { publishable_share_target: "native" }) do
          render FlatPack::Button::Component.new(
            text: Copy.t("share.native"),
            style: :secondary,
            size: :md,
            class: "w-full",
            aria: { label: Copy.t("share.native") },
            data: { action: "click->publishable-share#native" }
          )
        end
      end

      def link_button(name)
        href = ShareDestinations.hrefs(url: @sheet.url, title: @sheet.title, destinations: [name]).dig(0, 1)
        return if href.blank?

        content_tag(:div, class: "w-full") do
          render FlatPack::Button::Component.new(**link_options(name, href))
        end
      end

      def link_options(name, href)
        {
          text: Copy.t("share.#{name}"),
          href: href,
          target: (name == :email ? nil : "_blank"),
          rel: (name == :email ? nil : "noopener noreferrer"),
          style: :secondary,
          size: :md,
          class: "w-full",
          aria: { label: accessible_name(name) }
        }
      end

      def accessible_name(name)
        return Copy.t("share.share_by_email") if name == :email

        Copy.t("share.share_on", name: Copy.t("share.#{name}"))
      end
    end
  end
end
