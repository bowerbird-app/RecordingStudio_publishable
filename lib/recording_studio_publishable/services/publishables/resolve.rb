# frozen_string_literal: true

module RecordingStudioPublishable
  module Services
    module Publishables
      class Resolve < BaseService
        def initialize(uuid:, slug: nil)
          @uuid = uuid
          @slug = slug
        end

        private

        attr_reader :uuid, :slug

        def perform
          publishable_recording = RecordingStudio::Recording.find_by(
            id: uuid,
            recordable_type: RecordingStudioPublishable::Publishable.name,
            trashed_at: nil
          )
          return failure("Publishable recording was not found") unless publishable_recording

          publishable = publishable_recording.recordable
          return failure("Publishable recording is not currently public") unless publishable.currently_published?
          return failure("Publishable slug is stale") if slug.present? && slug != publishable.slug

          success(
            publishable_recording: publishable_recording,
            publishable: publishable,
            parent_recording: publishable_recording.parent_recording,
            parent_recordable: publishable_recording.parent_recording&.recordable
          )
        rescue StandardError => e
          failure(e)
        end
      end
    end
  end
end
