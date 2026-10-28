# frozen_string_literal: true

module RecordingStudio
  class ActorResolver
    def self.resolve_actor
      ->(actor = nil) { actor || Current.actor }
    end
  end
end