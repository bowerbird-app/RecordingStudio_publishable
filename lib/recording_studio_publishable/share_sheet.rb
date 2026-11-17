# frozen_string_literal: true

require_relative "share_preview"

module RecordingStudioPublishable
  ShareSheet = Data.define(:url, :title, :description, :destinations, :modal_size, :modal_id) do
    def self.for(recording, url:, destinations:, modal_size:)
      preview = SharePreview.for(recording)
      new(
        url: url,
        title: preview.title,
        description: preview.description,
        destinations: Array(destinations),
        modal_size: modal_size,
        modal_id: modal_id_for(recording)
      )
    end

    def self.modal_id_for(recording)
      "publishable-share-#{publishable_id_for(recording) || recording&.id}"
    end

    def self.publishable_id_for(recording)
      return unless recording.respond_to?(:publishable_child_recording)

      recording.publishable_child_recording&.id
    end
    private_class_method :publishable_id_for

    def include?(name)
      destinations.include?(name)
    end
  end
end
