# frozen_string_literal: true

require "securerandom"
require_relative "share_preview"

module RecordingStudioPublishable
  class ShareSheet
    def self.for(recording, url:, destinations:)
      preview = SharePreview.for(recording)
      new(
        url: url,
        title: preview.title,
        description: preview.description,
        destinations: Array(destinations),
        modal_id: "publishable-share-#{SecureRandom.hex(6)}"
      )
    end

    def initialize(url:, title:, description:, destinations:, modal_id:)
      @url = url
      @title = title
      @description = description
      @destinations = destinations
      @modal_id = modal_id
    end

    attr_reader :url, :title, :description, :destinations, :modal_id

    def include?(name)
      destinations.include?(name)
    end
  end
end
