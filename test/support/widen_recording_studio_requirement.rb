# frozen_string_literal: true

# Accessible, Attachable, Cache, Metrics, Root Switchable, Trashable, API,
# Admin, and Internationalization still require recording_studio below 5.
# No newer tag relaxes that. Widen the requirement when Bundler loads
# gemspecs so this app can resolve 6.1.0.
module WidenRecordingStudioRequirement
  def add_dependency(name, *requirements)
    if name.to_s == "recording_studio" && requirements.none? { |requirement| requirement.to_s.include?("6") }
      requirements = [">= 6.1.0"]
    end

    super
  end
end

unless Gem::Specification.ancestors.include?(WidenRecordingStudioRequirement)
  Gem::Specification.prepend(WidenRecordingStudioRequirement)
end
