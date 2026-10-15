# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    module StateOverrides
      STATES = %i[draft scheduled published].freeze
      ENTRY_KEYS = %i[style icon].freeze
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
        result = {}
        result[:style] = entry[:style].to_sym if entry[:style].present?
        result[:icon] = normalize_icon(entry[:icon]) if entry[:icon].present?
        result
      end

      def normalize_icon(icon)
        name = icon.to_s.tr("_", "-")
        return name if name.match?(ICON_PATTERN)

        raise ArgumentError, "Invalid quick actions icon: #{icon}"
      end
    end
  end
end
