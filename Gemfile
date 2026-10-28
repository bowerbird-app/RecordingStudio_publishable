# frozen_string_literal: true

source "https://rubygems.org"

require_relative "test/support/widen_recording_studio_requirement"

# Specify your gem's dependencies in recording_studio_publishable.gemspec
gemspec

# recording_studio is not published to RubyGems; resolve the gemspec pin from GitHub.
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.1.0"

gem "devise"
gem "flat_pack", ">= 0.1.315", github: "bowerbird-app/flatpack", tag: "v0.1.329"
gem "pg", "~> 1.1"
gem "puma"
gem "sprockets-rails"
gem "view_component", "4.19.0"

gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.21.0"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.15.0"
gem "recording_studio_cache", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.1"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics",
                                tag: "v0.6.1", require: false
gem "recording_studio_root_switchable", github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.10.0"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable",
                                  tag: "v0.11.3", require: false

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
