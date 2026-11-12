# frozen_string_literal: true

module RecordingStudioPublishable
  module ShareModal
    class Destinations < ViewComponent::Base
      def initialize(sheet:)
        super()
        @sheet = sheet
      end

      def call
        render(FlatPack::Stack::Component.new(gap: :sm, aria: { label: Copy.t("share.destinations_label") })) do
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
        render FlatPack::CopyButton::Component.new(
          text: @sheet.url,
          label: Copy.t("share.copy_link"),
          style: :primary,
          size: :md,
          # CopyButton applies class to its inline-flex host. A column
          # stretches the inner button across that full width.
          class: "w-full flex-col"
        )
      end

      def native_button
        render FlatPack::Button::Component.new(**native_options)
      end

      def native_options
        {
          text: Copy.t("share.native"),
          style: :secondary,
          size: :md,
          class: "hidden w-full",
          hidden: true,
          aria: { label: Copy.t("share.native") },
          data: { action: "click->publishable-share#native", publishable_share_target: "native" }
        }
      end

      def link_button(name)
        href = ShareDestinations.hrefs(url: @sheet.url, title: @sheet.title, destinations: [name]).dig(0, 1)
        return if href.blank?

        render FlatPack::Button::Component.new(**link_options(name, href))
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
