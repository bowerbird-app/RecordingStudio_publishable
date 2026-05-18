# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_publishable.gemspec
gem "devise"
gemspec

gem "puma"
gem "sprockets-rails"

gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v0.1.0-alpha"
gem "recording_studio_accessible", git: "https://github.com/bowerbird-app/RecordingStudio_accessible.git"
gem "recording_studio_attachable", git: "https://github.com/bowerbird-app/RecordingStudio_attachable.git"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
