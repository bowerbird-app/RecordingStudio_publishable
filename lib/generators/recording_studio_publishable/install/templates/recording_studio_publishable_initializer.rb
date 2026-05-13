# frozen_string_literal: true

RecordingStudioPublishable.configure do |config|
  # Use a host-app resolver that returns the current actor used for publishable management.
  # config.current_actor_resolver = ->(controller:) { Current.actor || controller.current_user }

  # Authorize management actions against the parent recording.
  # When RecordingStudioAccessible is installed, the default authorizer uses it automatically.
  # config.management_authorizer = lambda do |recording:, actor:, controller:|
  #   actor.present? && RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :edit)
  # end

  # Use the host app's preferred default time zone for schedule editing.
  # config.default_time_zone = "UTC"

  # Override the engine layout used by the edit publishable screen.
  # config.default_layout = "application"

  # Change the redirect status used when a stale slug is requested.
  # config.canonical_redirect_status = :moved_permanently
end
