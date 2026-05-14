# frozen_string_literal: true

require_relative "lib/recording_studio_publishable/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_publishable"
  spec.version     = RecordingStudioPublishable::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_publishable"
  spec.summary     = "Reusable publishable child recordings for RecordingStudio"
  spec.description = "Adds publishable child recordings, current-state helpers, " \
                     "public routing, and FlatPack management UI for RecordingStudio-backed content."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_publishable"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_publishable/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", "~> 8.1.0"
end
