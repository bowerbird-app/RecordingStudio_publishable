# frozen_string_literal: true

require "recording_studio"
require "recording_studio_publishable/version"
require "recording_studio_publishable/hooks"
require "recording_studio_publishable/configuration"
require "recording_studio_publishable/trashed_at"
require "recording_studio_publishable/routing"
require "recording_studio_publishable/parent_recordable"
require "recording_studio_publishable/recording_extensions"
require "recording_studio_publishable/actor_resolver"
require "recording_studio_publishable/recordable_types_service"
require "recording_studio_publishable/services/base_service"
require "recording_studio_publishable/services/publishables/ensure_child"
require "recording_studio_publishable/services/publishables/update"
require "recording_studio_publishable/services/publishables/transition"
require "recording_studio_publishable/services/publishables/resolve"
require "recording_studio_publishable/engine"
require "recording_studio/capabilities/publishable"

module RecordingStudioPublishable
  class << self
    def install_recording_capabilities!
      return unless defined?(RecordingStudio::Recording)

      RecordingStudio.apply_capabilities!
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

RecordingStudioPublishable.install_recording_capabilities!
