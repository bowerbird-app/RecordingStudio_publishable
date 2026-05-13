# frozen_string_literal: true

module RecordingStudioPublishable
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    helper RecordingStudioPublishable::ApplicationHelper
    layout -> { RecordingStudioPublishable.configuration.default_layout }

    private

    def current_publishable_actor
      RecordingStudioPublishable.configuration.actor_for(controller: self)
    end

    def authorize_publishable_management!(recording)
      return if RecordingStudioPublishable.configuration.authorize_management?(
        recording: recording,
        actor: current_publishable_actor,
        controller: self
      )

      head :forbidden
    end
  end
end
