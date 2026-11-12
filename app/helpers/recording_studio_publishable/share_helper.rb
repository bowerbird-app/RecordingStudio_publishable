# frozen_string_literal: true

module RecordingStudioPublishable
  module ShareHelper
    def publishable_share_button(recording, **overrides)
      url = ShareButtonUrl.absolute(recording, base_url: share_request_base_url)
      return if url.blank?

      face = ShareButton.resolve(RecordingStudioPublishable.configuration.share_button, **overrides)
      button = render(FlatPack::CopyButton::Component.new(**face.component_arguments, text: url))
      return button unless face.icon_only

      render(FlatPack::Tooltip::Component.new(text: face.label).with_content(button))
    end

    private

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
