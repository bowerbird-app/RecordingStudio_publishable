# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in gem_template.gemspec
gem "devise"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", ref: "7667687155bf05ab41b66dfccae330dc3834c39c"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.74"
gem "pg", "~> 1.1"
gemspec

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
