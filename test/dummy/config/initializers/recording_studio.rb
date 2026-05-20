# frozen_string_literal: true

return unless defined?(RecordingStudio) && RecordingStudio.respond_to?(:configure)

RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "Folder",
    "Page",
    "RecordingStudioPublishable::Publishable",
    "RecordingStudioAttachable::Attachment"
  ]
  config.actor = RecordingStudio::ActorResolver.resolve_actor
  config.event_notifications_enabled = true
  config.idempotency_mode = :return_existing
  config.include_children = false
  config.recordable_dup_strategy = :dup
end
