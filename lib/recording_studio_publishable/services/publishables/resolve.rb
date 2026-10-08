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
            RecordingStudioPublishable::TrashedAt.merge_active(
              id: uuid,
              recordable_type: RecordingStudioPublishable::Publishable.name
            )
          )
          return failure(Copy.t("errors.recording_not_found")) unless publishable_recording

          publishable = publishable_recording.recordable
          return failure(Copy.t("errors.not_public")) unless publishable.currently_published?
          return failure(Copy.t("errors.slug_stale")) if slug.present? && slug != publishable.slug

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
