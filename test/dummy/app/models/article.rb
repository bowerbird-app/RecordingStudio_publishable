class Article < ApplicationRecord
  include RecordingStudioPublishable::ParentRecordable

  recording_studio_publishable(
    public_controller: "articles",
    public_action: :show,
    path: "/blogs/:uuid/:slug",
    schedule: true,
    seo: true
  )
end