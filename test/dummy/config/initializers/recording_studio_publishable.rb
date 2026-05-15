# frozen_string_literal: true

RecordingStudioPublishable.configure do |config|
  config.register_public_renderer(
    "Page",
    controller: "pages",
    action: :show
  )

  config.register_public_renderer(
    "Article",
    controller: "articles",
    action: :show
  )

  config.management_authorizer = lambda do |recording:, actor:, **|
    actor.present? && recording.present? && actor.email == "admin@admin.com"
  end
end
