# frozen_string_literal: true

return unless defined?(RecordingStudio) && RecordingStudio.respond_to?(:configure)

RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "Folder",
    "Page",
    "Article",
    "RecordingStudioPublishable::Publishable",
    "RecordingStudioAttachable::Attachment"
  ]
  config.require_recordable_declarations = true
  config.actor = -> { Current.actor }
  config.impersonator = -> { Current.impersonator }
  config.event_notifications_enabled = true
  config.idempotency_mode = :return_existing
  config.include_children = false
  config.recordable_dup_strategy = :dup
end
