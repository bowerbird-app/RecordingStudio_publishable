# frozen_string_literal: true

module RecordingStudioPublishable
  class ShareButtonSettings
    KEYS = %i[style icon size icon_only label class].freeze
    DEFAULTS = { style: :secondary, icon: "arrow-up-tray", size: :md, icon_only: true }.freeze
    SIZES = %i[sm md lg].freeze
    LABEL_LIMIT = 80
    NAME_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

    class << self
      def parse(value)
        return {} if blank?(value)

        hash_from(value).each_with_object({}) do |(key, raw), parsed|
          parsed[setting_name(key)] = cast(setting_name(key), raw)
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

      def cast(name, raw)
        case name
        when :style then cast_style(raw)
        when :icon then cast_name(:icon, raw)
        when :size then cast_size(raw)
        when :icon_only then cast_icon_only(raw)
        when :label then cast_label(raw)
        when :class then cast_class(raw)
        end
      end

      def cast_style(raw)
        style = cast_name(:style, raw).to_sym
        return style unless defined?(FlatPack::Button::StyleRegistry)
        return style if FlatPack::Button::StyleRegistry.known?(style)

        raise ArgumentError, FlatPack::Button::StyleRegistry.invalid_style_message(style)
      end

      def cast_name(name, raw)
        text = raw.to_s
        raise ArgumentError, "#{name} must be a name" unless named?(raw, text)

        text
      end

      def named?(raw, text)
        (raw.is_a?(String) || raw.is_a?(Symbol)) && text.match?(NAME_PATTERN)
      end

      def cast_size(raw)
        size = raw.to_s.to_sym
        return size if SIZES.include?(size)

        raise ArgumentError, "size must be sm, md, or lg"
      end

      def cast_icon_only(raw)
        return raw if [true, false].include?(raw)

        raise ArgumentError, "icon_only must be true or false"
      end

      def cast_label(raw)
        text = raw.to_s.strip
        raise ArgumentError, "label must be text" unless raw.is_a?(String) || raw.is_a?(Symbol)
        raise ArgumentError, "label is blank" if text.empty?
        raise ArgumentError, "label is too long" if text.length > LABEL_LIMIT

        text
      end

      def cast_class(raw)
        raise ArgumentError, "class must be text" unless raw.is_a?(String)

        raw.strip.presence
      end
    end
  end
end
