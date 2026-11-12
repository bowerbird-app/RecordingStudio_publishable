# frozen_string_literal: true

module RecordingStudioPublishable
  class SharePreview
    def self.for(recording)
      publishable = recording.respond_to?(:current_publishable) ? recording.current_publishable : nil
      recordable = recording.respond_to?(:recordable) ? recording.recordable : nil
      new(
        title: text(publishable&.try(:social_title), publishable&.try(:seo_title), recordable&.try(:title)),
        description: text(publishable&.try(:social_description), publishable&.try(:seo_description))
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
