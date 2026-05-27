class Page < ApplicationRecord
  include RecordingStudioPublishable::ParentRecordable

  recording_studio_publishable(
    public_controller: "pages",
    public_action: :show,
    schedule: true,
    seo: false
  )
end
