# frozen_string_literal: true

require_relative "description"

module RecordingStudioPublishable
  class SharePreview
    def self.for(recording)
      publishable = recording.respond_to?(:current_publishable) ? recording.current_publishable : nil
      recordable = recording.respond_to?(:recordable) ? recording.recordable : nil
      description = Description.for(publishable: publishable, recordable: recordable).social
      new(
        title: text(publishable&.try(:social_title), publishable&.try(:seo_title), recordable&.try(:title)),
        description: description.to_s
      )
    end

    def self.text(*values)
      values.each do |value|
        string = value.to_s.strip
        return string unless string.empty?
      end
      ""
    end

    def initialize(title:, description:)
      @title = title
      @description = description
    end

    attr_reader :title, :description
  end
end
