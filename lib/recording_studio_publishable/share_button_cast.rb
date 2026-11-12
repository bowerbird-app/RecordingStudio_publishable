# frozen_string_literal: true

require_relative "share_destinations"

module RecordingStudioPublishable
  module ShareButtonCast
    SIZES = %i[sm md lg].freeze
    MODES = %i[copy modal].freeze
    LABEL_LIMIT = 80
    NAME_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

    class << self
      def cast(name, raw)
        return css(raw) if name == :class

        public_send(name, raw)
      end

      def style(raw)
        name = cast_name(:style, raw).to_sym
        return name unless defined?(FlatPack::Button::StyleRegistry)
        return name if FlatPack::Button::StyleRegistry.known?(name)

        raise ArgumentError, FlatPack::Button::StyleRegistry.invalid_style_message(name)
      end

      def icon(raw)
        cast_name(:icon, raw)
      end

      def size(raw)
        value = raw.to_s.to_sym
        return value if SIZES.include?(value)

        raise ArgumentError, "size must be sm, md, or lg"
      end

      def icon_only(raw)
        return raw if [true, false].include?(raw)

        raise ArgumentError, "icon_only must be true or false"
      end

      def label(raw)
        text = raw.to_s.strip
        raise ArgumentError, "label must be text" unless raw.is_a?(String) || raw.is_a?(Symbol)
        raise ArgumentError, "label is blank" if text.empty?
        raise ArgumentError, "label is too long" if text.length > LABEL_LIMIT

        text
      end

      def css(raw)
        raise ArgumentError, "class must be text" unless raw.is_a?(String)

        raw.strip.presence
      end

      def mode(raw)
        value = raw.to_sym
        return value if MODES.include?(value)

        raise ArgumentError, "mode must be copy or modal"
      end

      def destinations(raw)
        raise ArgumentError, "destinations must be a list" unless raw.is_a?(Array)

        raw.map { |item| destination_name(item) }.uniq.freeze
      end

      private

      def cast_name(name, raw)
        text = raw.to_s
        raise ArgumentError, "#{name} must be a name" unless named?(raw, text)

        text
      end

      def named?(raw, text)
        (raw.is_a?(String) || raw.is_a?(Symbol)) && text.match?(NAME_PATTERN)
      end

      def destination_name(item)
        name = item.to_sym
        return name if ShareDestinations::NAMES.include?(name)

        raise ArgumentError, "unknown share destination: #{item}"
      end
    end
  end
end
