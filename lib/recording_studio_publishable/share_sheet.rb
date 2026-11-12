# frozen_string_literal: true

require "securerandom"
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
        modal_id: "publishable-share-#{SecureRandom.hex(6)}"
      )
    end

    def include?(name)
      destinations.include?(name)
    end
  end
end
