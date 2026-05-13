class Page < ApplicationRecord
  include RecordingStudioPublishable::ParentRecordable

  recording_studio_publishable
end
