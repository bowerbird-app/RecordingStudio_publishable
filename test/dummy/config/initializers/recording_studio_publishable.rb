# frozen_string_literal: true

RecordingStudioPublishable.configure do |config|
  # nil falls through to RecordingStudio.configuration.layout, then
  # recording_studio/default_layout. Do not hard-code that layout name.
  config.layout = nil

  config.management_authorizer = lambda do |recording:, actor:, **|
    actor.present? &&
      recording.present? &&
      defined?(RecordingStudioAccessible) &&
      RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :edit)
  end

  config.management_close_url_resolver = lambda do |controller:, recording:, **|
    controller.main_app.root_path
  end
end
