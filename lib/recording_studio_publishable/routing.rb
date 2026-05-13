# frozen_string_literal: true

module RecordingStudioPublishable
  module Routing
    class << self
      def path_for(publishable_recording:, publishable: nil, parent_recordable_type: nil)
        publishable ||= publishable_recording.recordable
        parent_recordable_type ||= publishable_recording.parent_recording&.recordable_type
        template = RecordingStudioPublishable.configuration.public_path_for(parent_recordable_type)

        template
          .gsub(":uuid", publishable_recording.id.to_s)
          .gsub(":slug", publishable.slug.to_s)
      end
    end
  end
end
