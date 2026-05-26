# frozen_string_literal: true

RecordingStudioPublishable.configure do |config|
  config.management_authorizer = lambda do |recording:, actor:, **|
    actor.present? && recording.present? && actor.email == "admin@admin.com"
  end
end
