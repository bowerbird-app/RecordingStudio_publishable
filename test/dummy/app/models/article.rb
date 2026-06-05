class Article < ApplicationRecord
  recording_studio_recordable label: "Article", root: false, allowed_parent_types: ["Workspace", "Folder", "Article"]

  include RecordingStudioPublishable::ParentRecordable

  recording_studio_publishable(
    public_controller: "articles",
    public_action: :show,
    path: "/blogs/:uuid/:slug",
    schedule: true,
    seo: true
  )
end