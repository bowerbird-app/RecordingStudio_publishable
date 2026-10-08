# frozen_string_literal: true

if defined?(RecordingStudioInternationalization)
  RecordingStudioInternationalization.configure do |config|
    config.available_locales = {
      en: { name: "English" },
      fr: { name: "Français" }
    }
    config.default_locale = :en
  end
end
