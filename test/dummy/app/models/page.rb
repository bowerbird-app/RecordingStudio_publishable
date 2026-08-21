class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: ["Workspace", "Folder", "Page"]

  include RecordingStudio::Capabilities::Publishable.to(
    public_controller: "pages",
    public_action: :show,
    schedule: true,
    seo: false
  )
end
