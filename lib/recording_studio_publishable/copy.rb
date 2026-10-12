# frozen_string_literal: true

require "erb"
require "i18n"
require "active_support/core_ext/string/output_safety"
require "recording_studio_publishable/copy/english"

module RecordingStudioPublishable
  # Rails I18n lookups for Publishable user-facing copy. Every call passes
  # `default:` English (from ENGLISH or an explicit caller default) so a host
  # locale without a fallback never shows "translation missing".
  module Copy
    PREFIX = "recording_studio.publishable"
    UNSET = Object.new.freeze

    module_function

    def t(key, **options)
      full_key = "#{PREFIX}.#{key}"
      english = ENGLISH[key.to_s]
      options = { default: english }.merge(options) if english && !options.key?(:default)

      return I18n.t(full_key, **options) unless key.to_s.end_with?("_html")

      escaped = options.transform_values { |value| value.is_a?(String) ? ERB::Util.html_escape(value) : value }
      I18n.t(full_key, **escaped).to_s.html_safe
    end

    def l(object, **)
      I18n.l(object, **)
    end

    def provided?(value)
      !value.equal?(UNSET)
    end

    def value(override, key, **)
      provided?(override) ? override : t(key, **)
    end

    # Host config that still matches the English default follows the locale.
    # A different string (including blank after presence) is host copy and wins.
    def defaulted(value, default, key, **)
      return t(key, **) if value.nil? || value == default

      value
    end

    def attribute_name(attribute)
      name = attribute.to_s
      t("attributes.#{name}", default: name.humanize)
    end

    def attribute_invalid(attribute)
      t("errors.attribute_invalid", attribute: attribute_name(attribute))
    end
  end
end
