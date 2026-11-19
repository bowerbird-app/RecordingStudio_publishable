# frozen_string_literal: true

require "action_view"
require "loofah"

module RecordingStudioPublishable
  class Description
    LENGTH = 160

    def self.for(publishable:, recordable:)
      new(publishable: publishable, recordable: recordable)
    end

    def initialize(publishable:, recordable:)
      @publishable = publishable
      @recordable = recordable
    end

    def meta(explicit: nil)
      first_present(explicit, read(:seo_description)) || recordable_text
    end

    def social(explicit: nil)
      first_present(explicit, read(:social_description), read(:seo_description)) || recordable_text
    end

    private

    def read(name)
      @publishable&.try(name)
    end

    def first_present(*values)
      values.each do |value|
        text = value.to_s
        return text if text.present?
      end

      nil
    end

    def recordable_text
      return @recordable_text if defined?(@recordable_text)

      @recordable_text = normalize_recordable
    end

    def normalize_recordable
      raw = recordable_description_value
      return if raw.nil?

      text = ActionView::Base.full_sanitizer.sanitize(without_hidden_markup(raw)).squish
      return if text.blank?

      text.truncate(LENGTH, separator: /\s/, omission: "")
    end

    def without_hidden_markup(raw)
      fragment = Loofah.fragment(raw.to_s)
      fragment.css("script, style").remove
      fragment.to_html
    end

    def recordable_description_value
      return if @recordable.blank?

      @recordable.try(:publishable_description)
    rescue StandardError
      nil
    end
  end
end
