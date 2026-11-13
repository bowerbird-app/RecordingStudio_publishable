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
          return failure(Copy.t("errors.unknown_transition")) unless attributes
          return success(parent_recording.publishable_child_recording) if skip_write?

          attributes = attributes.dup
          attributes[:publish_at] = Time.current if transition == "publish"

          Update.call(parent_recording: parent_recording, attributes: attributes, actor: actor)
        end

        def skip_write?
          case transition
          when "publish" then parent_recording.currently_published?
          when "unpublish" then already_draft?
          else false
          end
        end

        def already_draft?
          publishable = parent_recording.current_publishable
          publishable.nil? || publishable.draft_state?
        end
      end
    end
  end
end
