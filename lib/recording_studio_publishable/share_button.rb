# frozen_string_literal: true

require_relative "share_button_settings"

module RecordingStudioPublishable
  module ShareButton
    Face = Data.define(:style, :icon, :size, :icon_only, :label, :html, :mode, :destinations) do
      def component_arguments
        html.merge(label: label, icon: icon, icon_only: icon_only, style: style, size: size)
      end
    end

    class << self
      def parse(value)
        ShareButtonSettings.parse(value)
      end

      def resolve(config, **overrides)
        stored, chosen, html = parts(config, overrides)
        Face.new(**attributes_for(stored, chosen, html))
      end

      private

      def parts(config, overrides)
        stored = config || {}
        options = normalize_overrides(overrides)
        [stored, parse(options.slice(*ShareButtonSettings::KEYS)), html_options(options)]
      end

      def html_options(options)
        options.except(*ShareButtonSettings::KEYS)
      end

      def attributes_for(stored, chosen, html)
        merged = defaults.merge(picked(stored)).merge(picked(chosen))
        appearance(merged).merge(label: chosen_label(stored, chosen), html: html_with_class(html, stored, chosen))
      end

      def appearance(merged)
        {
          style: merged.fetch(:style),
          icon: merged.fetch(:icon),
          size: merged.fetch(:size),
          icon_only: merged.fetch(:icon_only),
          mode: merged.fetch(:mode),
          destinations: merged.fetch(:destinations)
        }
      end

      def defaults
        ShareButtonSettings::DEFAULTS
      end

      def picked(settings)
        settings.slice(*defaults.keys)
      end

      def html_with_class(html, stored, chosen)
        css = chosen.key?(:class) ? chosen[:class] : stored[:class]
        return html if css.blank?

        html.merge(class: css)
      end

      def chosen_label(stored, chosen)
        return chosen[:label] if chosen.key?(:label)
        return stored[:label] if stored.key?(:label)

        Copy.t("share.label")
      end

      def normalize_overrides(overrides)
        options = overrides.symbolize_keys
        apply_style_alias(options)
        apply_label_alias(options)
        options
      end

      def apply_style_alias(options)
        return if options.key?(:style) || !options.key?(:variant)

        options[:style] = options.delete(:variant)
      end

      def apply_label_alias(options)
        options.delete(:variant)
        return if options.key?(:label) || !options.key?(:text)

        options[:label] = options.delete(:text)
      end
    end
  end
end
