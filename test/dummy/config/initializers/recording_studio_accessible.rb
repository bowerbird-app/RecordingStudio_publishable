# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  actor_types = ["User"]
  actor_types << "RecordingStudioApi::ApiClient" if defined?(RecordingStudioApi)
  config.access_actor_types = actor_types
end
