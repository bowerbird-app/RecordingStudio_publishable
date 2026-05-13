# frozen_string_literal: true

module RecordingStudioPublishable
  module Services
    module Publishables
      class Transition < BaseService
        TRANSITIONS = {
          "publish" => { status: "published", publish_at: nil, unpublish_at: nil },
          "schedule" => { status: "scheduled" },
          "unpublish" => { status: "unpublished" },
          "draft" => { status: "draft", publish_at: nil, unpublish_at: nil }
        }.freeze

        def initialize(parent_recording:, transition:, actor: nil)
          @parent_recording = parent_recording
          @transition = transition.to_s
          @actor = actor
        end

        private

        attr_reader :parent_recording, :transition, :actor

        def perform
          attributes = TRANSITIONS[transition]
          return failure("Unknown publishable transition") unless attributes

          if transition == "schedule"
            ensure_result = EnsureChild.call(parent_recording: parent_recording, actor: actor)
            return ensure_result if ensure_result.failure?

            current_publishable = ensure_result.value.recordable
            unless current_publishable.publish_at.present? && current_publishable.publish_at.future?
              return failure("Set a future publish at time before marking content as scheduled")
            end
          end

          Update.call(parent_recording: parent_recording, attributes: attributes, actor: actor)
        end
      end
    end
  end
end
