class Widget < ApplicationRecord
  include RecordingStudioPublishable::ParentRecordable

  recording_studio_publishable(
    public_controller: "widgets",
    public_action: :show,
    url: false,
    schedule: true,
    seo: false
  )
end
