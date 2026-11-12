# frozen_string_literal: true

module RecordingStudioPublishable
  module ShareHelper
    def publishable_share_button(recording, **overrides)
      url = ShareButtonUrl.absolute(recording, base_url: share_request_base_url)
      return if url.blank?

      face = ShareButton.resolve(RecordingStudioPublishable.configuration.share_button, **overrides)
      return copy_share_button(face, url) unless face.mode == :modal

      modal_share_button(recording, face, url)
    end

    private

    def copy_share_button(face, url)
      button = render(FlatPack::CopyButton::Component.new(**face.component_arguments, text: url))
      return button unless face.icon_only

      render(FlatPack::Tooltip::Component.new(text: face.label).with_content(button))
    end

    def modal_share_button(recording, face, url)
      sheet = ShareSheet.for(recording, url: url, destinations: face.destinations)
      safe_join([modal_trigger(face, sheet.modal_id), render(ShareModal::Component.new(sheet: sheet))])
    end

    def modal_trigger(face, modal_id)
      button = render(FlatPack::Button::Component.new(**trigger_arguments(face, modal_id)))
      return button unless face.icon_only

      render(FlatPack::Tooltip::Component.new(text: face.label).with_content(button))
    end

    def trigger_arguments(face, modal_id)
      face.html.merge(
        text: face.label,
        icon: face.icon,
        icon_only: face.icon_only,
        style: face.style,
        size: face.size,
        aria: { label: face.label, haspopup: "dialog", controls: modal_id },
        data: { modal_id: modal_id }
      )
    end

    def share_request_base_url
      return unless respond_to?(:request)

      current = request
      return unless current.respond_to?(:base_url)

      current.base_url.presence
    rescue StandardError
      nil
    end
  end
end
