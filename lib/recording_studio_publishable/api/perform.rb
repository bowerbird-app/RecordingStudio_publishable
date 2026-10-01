# frozen_string_literal: true

module RecordingStudioPublishable
  module Api
    module Perform
      Outcome = Data.define(:parent, :child_recording, :publishable)

      class Bound
        def initialize(action_name)
          @action_name = action_name
        end

        attr_reader :action_name

        def call(context)
          Perform.apply(context, action_name)
        end
      end

      class << self
        def apply(context, action_name)
          refuse_child!(context, action_name)
          result = call_service(Api::ACTIONS.fetch(action_name), context)
          return success_outcome(context, result) if result.success?

          message = result.error.to_s
          Api.invalid_input!(message, details: failure_details(result, message))
        end

        private

        def call_service(spec, context)
          case spec.fetch(:service)
          when :transition then transition(spec, context)
          when :update then update(context)
          end
        end

        def transition(spec, context)
          RecordingStudioPublishable::Services::Publishables::Transition.call(
            parent_recording: context.recording,
            transition: spec.fetch(:transition),
            actor: context.api_client
          )
        end

        def update(context)
          RecordingStudioPublishable::Services::Publishables::Update.call(
            parent_recording: context.recording,
            attributes: context.params,
            actor: context.api_client
          )
        end

        def success_outcome(context, result)
          child = result.value
          Outcome.new(parent: context.recording, child_recording: child, publishable: child.recordable)
        end

        def failure_details(result, message)
          errors = result.respond_to?(:errors) ? result.errors : nil
          return errors if errors.is_a?(Array) && !errors.empty?

          [message]
        end

        def refuse_child!(context, action_name)
          return unless publishable_child?(context.recording)

          raise unsupported_action_error, child_message(action_name)
        end

        def publishable_child?(recording)
          recording.recordable_type == RecordingStudioPublishable::Publishable.name
        end

        def child_message(action_name)
          "#{action_name} applies to the parent recording, not the publishable child"
        end

        def unsupported_action_error
          if defined?(RecordingStudioApi::UnsupportedActionError)
            RecordingStudioApi::UnsupportedActionError
          else
            StandardError
          end
        end
      end
    end
  end
end
