# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_publishable.gemspec
gemspec

# recording_studio is not published to RubyGems; resolve the gemspec pin from GitHub.
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"

gem "devise"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.133"
gem "pg", "~> 1.1"
gem "puma"
gem "sprockets-rails"

gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.6.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "0.4.0"
gem "recording_studio_root_switchable", github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.5.0"

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
