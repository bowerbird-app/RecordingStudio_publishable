# frozen_string_literal: true

# BEGIN RecordingStudioPublishable seeds
# Example seed: attach publishable state to an existing parent recording.
# Replace the lookup below with app-specific records if you want this to run by default.
if defined?(RecordingStudio::Recording)
  parent_recording = RecordingStudio::Recording.find_by(id: ENV.fetch("RECORDING_STUDIO_PUBLISHABLE_PARENT_ID", nil))

  if parent_recording.present?
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: {
        slug: "example-#{parent_recording.id}",
        status: "published"
      }
    )
  end
end
# END RecordingStudioPublishable seeds
