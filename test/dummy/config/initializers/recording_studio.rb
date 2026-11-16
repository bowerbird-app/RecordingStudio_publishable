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
# recording_studio_api.rb sets admin_root_recordable_type_names after this file
# loads. Register AdminApi only once that list is present.
if defined?(RecordingStudioApi::Engine)
  Rails.application.config.to_prepare do
    next unless RecordingStudioApi.configuration.admin_root_recordable_type_names.present?

    admin_api = RecordingStudioApi::Engine::ADMIN_API_RECORDABLE_TYPE_NAME
    registered = Array(RecordingStudio.configuration.recordable_types).map(&:to_s)
    next if registered.include?(admin_api)

    RecordingStudio.configuration.recordable_types = registered + [ admin_api ]
  end
end

RecordingStudio.configure do |config|
  config.recordable_types = recordable_types
  config.require_recordable_declarations = true
  # Recording Studio 6.5 denies writes unless authorize_write is set.
  # The dummy keeps the previous open writes used by the test host.
  config.allow_unauthorized_writes = true
  config.app_name = "Publishable Demo" if config.respond_to?(:app_name=)
  config.actor = -> { Current.actor }
  config.impersonator = -> { Current.impersonator }
  config.event_notifications_enabled = true
  config.idempotency_mode = :return_existing
  config.recordable_dup_strategy = :dup
end
