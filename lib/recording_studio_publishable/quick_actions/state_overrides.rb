# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    module StateOverrides
      STATES = %i[draft scheduled published].freeze
      ENTRY_KEYS = %i[style icon icon_variant icon_style].freeze
      ICON_VARIANTS = %i[outline solid mini micro].freeze
      ICON_STYLES = %i[primary success warning danger].freeze
      ICON_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

      module_function

      def normalize(value)
        return {} if blank?(value)
        raise ArgumentError, "quick actions states must be a Hash" unless value.respond_to?(:to_h)

        value.to_h.each_with_object({}) do |(key, entry), result|
          state = key.to_sym
          unless STATES.include?(state)
            raise ArgumentError, "Invalid quick actions state: #{key}. Must be one of: #{STATES.join(', ')}"
          end

          result[state] = normalize_entry(entry)
        end
      end

      def normalize_entry(entry)
        return {} if blank?(entry)
        raise ArgumentError, "quick actions state override must be a Hash" unless entry.respond_to?(:to_h)

        symbolized = entry.to_h.transform_keys(&:to_sym)
        unknown = symbolized.keys - ENTRY_KEYS
        raise ArgumentError, "Unknown quick actions state keys: #{unknown.join(', ')}" if unknown.any?

        compact_entry(symbolized)
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      def compact_entry(entry)
        {
          style: symbol_or_nil(entry[:style]),
          icon: icon_or_nil(entry[:icon]),
          icon_variant: choice_or_nil(entry[:icon_variant], ICON_VARIANTS, "icon variant"),
          icon_style: choice_or_nil(entry[:icon_style], ICON_STYLES, "icon style")
        }.compact
      end

      def symbol_or_nil(value)
        value.to_sym if value.present?
      end

      def icon_or_nil(value)
        normalize_icon(value) if value.present?
      end

      def choice_or_nil(value, allowed, label)
        return if value.blank?

        choice = value.to_sym
        return choice if allowed.include?(choice)

        raise ArgumentError, "Invalid quick actions #{label}: #{value}. Must be one of: #{allowed.join(', ')}"
      end

      def normalize_icon(icon)
        name = icon.to_s.tr("_", "-")
        return name if name.match?(ICON_PATTERN)

        raise ArgumentError, "Invalid quick actions icon: #{icon}"
      end
    end
  end
end
