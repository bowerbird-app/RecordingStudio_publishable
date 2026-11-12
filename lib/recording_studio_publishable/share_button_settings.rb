# frozen_string_literal: true

require_relative "share_button_cast"
require_relative "share_destinations"

module RecordingStudioPublishable
  class ShareButtonSettings
    KEYS = %i[style icon size icon_only label class mode destinations modal_size].freeze
    DEFAULTS = {
      style: :secondary,
      icon: "arrow-up-tray",
      size: :md,
      icon_only: true,
      mode: :copy,
      destinations: ShareDestinations::NAMES,
      modal_size: :sm
    }.freeze

    class << self
      def parse(value)
        return {} if blank?(value)

        hash_from(value).each_with_object({}) do |(key, raw), parsed|
          name = setting_name(key)
          parsed[name] = ShareButtonCast.cast(name, raw)
        end
      end

      private

      def setting_name(key)
        name = key.to_sym
        return name if KEYS.include?(name)

        raise ArgumentError, "unknown share button setting: #{key}"
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      def hash_from(value)
        raise ArgumentError, "share button settings must be a Hash" unless value.respond_to?(:to_hash)

        value.to_hash
      end
    end
  end
end
