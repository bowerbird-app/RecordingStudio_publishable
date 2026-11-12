# frozen_string_literal: true

module RecordingStudioPublishable
  module ShareModal
    class Component < ViewComponent::Base
      def initialize(sheet:)
        super()
        @sheet = sheet
      end

      def call
        render(modal)
      end

      private

      def modal
        content = sheet_body
        FlatPack::Modal::Component.new(
          id: @sheet.modal_id,
          title: Copy.t("share.modal_title"),
          size: :md
        ).tap do |sheet|
          sheet.body { content }
        end
      end

      def sheet_body
        content_tag(:div, class: "flex flex-col gap-5", **controller_attributes) do
          safe_join([preview, actions].compact)
        end
      end

      def controller_attributes
        {
          data: {
            controller: "publishable-share",
            publishable_share_url_value: @sheet.url,
            publishable_share_title_value: @sheet.title,
            publishable_share_text_value: @sheet.description
          }
        }
      end

      def preview
        return if @sheet.title.blank? && @sheet.description.blank?

        content_tag(:div, class: "min-w-0") do
          safe_join([title_tag, description_tag].compact)
        end
      end

      def title_tag
        return if @sheet.title.blank?

        content_tag(:p, @sheet.title, class: "text-base font-semibold")
      end

      def description_tag
        return if @sheet.description.blank?

        content_tag(:p, @sheet.description, class: "mt-1 text-sm")
      end

      def actions
        render(Destinations.new(sheet: @sheet))
      end
    end
  end
end
