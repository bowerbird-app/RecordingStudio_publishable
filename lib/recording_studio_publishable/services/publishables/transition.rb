# frozen_string_literal: true

module RecordingStudioPublishable
  module Services
    module Publishables
      class Transition < BaseService
        TRANSITIONS = {
          "publish" => { status: "published", unpublish_at: nil },
          "schedule" => { status: "published" },
          "unpublish" => { status: "draft" },
          "draft" => { status: "draft" }
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

          attributes = attributes.dup
          attributes[:publish_at] = Time.current if transition == "publish"

          Update.call(parent_recording: parent_recording, attributes: attributes, actor: actor)
        end
      end
    end
  end
end
