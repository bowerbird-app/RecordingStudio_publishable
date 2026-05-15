class Article < ApplicationRecord
  include RecordingStudioPublishable::ParentRecordable

  recording_studio_publishable
end