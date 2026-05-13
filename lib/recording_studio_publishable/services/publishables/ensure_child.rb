# frozen_string_literal: true

module RecordingStudioPublishable
  module Services
    module Publishables
      class EnsureChild < BaseService
        def initialize(parent_recording:, actor: nil)
          @parent_recording = parent_recording
          @actor = actor
        end

        private

        attr_reader :parent_recording, :actor

        def perform
          return failure("Parent recording is required") unless parent_recording

          existing_recording = parent_recording.publishable_child_recording
          return success(existing_recording) if existing_recording

          root_recording = parent_recording.root_recording || parent_recording
          publishable_recording = root_recording.record(
            RecordingStudioPublishable::Publishable,
            actor: actor,
            parent_recording: parent_recording,
            metadata: { source: "recording_studio_publishable.ensure_child" }
          ) do |publishable|
            publishable.slug = default_slug
            publishable.status = :draft
            publishable.time_zone = RecordingStudioPublishable.configuration.default_time_zone
          end

          success(publishable_recording)
        rescue ActiveRecord::RecordNotUnique
          success(parent_recording.reload.publishable_child_recording)
        rescue StandardError => e
          failure(e)
        end

        def service_args
          { parent_recording_id: parent_recording&.id }
        end

        def default_slug
          candidate = if parent_recording.recordable.respond_to?(:slug)
                        parent_recording.recordable.slug
                      elsif parent_recording.recordable.respond_to?(:title)
                        parent_recording.recordable.title
                      elsif parent_recording.recordable.respond_to?(:name)
                        parent_recording.recordable.name
                      end

          candidate.to_s.parameterize.presence || "recording-#{parent_recording.id.to_s.first(8)}"
        end
      end
    end
  end
end
