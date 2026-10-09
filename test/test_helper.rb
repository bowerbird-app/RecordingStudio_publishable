# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

ENV["RAILS_ENV"] ||= "test"

require_relative "simplecov_helper"
require "minitest/autorun"
require "minitest/mock"
require "rails"
require "i18n"
require "recording_studio_publishable"

# Locale files come from the engine's config/locales via Rails. Do not append
# the gem path here by hand — that can reorder load_path and clobber host overrides.
I18n.available_locales = Array(I18n.available_locales) | %i[en]
I18n.default_locale = :en
I18n.backend.load_translations if I18n.load_path.any?
