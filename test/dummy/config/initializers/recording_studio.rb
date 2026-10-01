# frozen_string_literal: true

return unless defined?(RecordingStudio) && RecordingStudio.respond_to?(:configure)

recordable_types = [
  "Workspace",
  "Folder",
  "Page",
  "Article",
  "RecordingStudioPublishable::Publishable",
  "RecordingStudioAttachable::Attachment"
]
if defined?(RecordingStudioApi::Engine)
  recordable_types << RecordingStudioApi::Engine::ADMIN_API_RECORDABLE_TYPE_NAME
end

RecordingStudio.configure do |config|
  config.recordable_types = recordable_types
  config.require_recordable_declarations = true
  config.app_name = "Publishable Demo" if config.respond_to?(:app_name=)
  config.actor = -> { Current.actor }
  config.impersonator = -> { Current.impersonator }
  config.event_notifications_enabled = true
  config.idempotency_mode = :return_existing
  config.recordable_dup_strategy = :dup
end
