# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    class Component < ViewComponent::Base
      def initialize(recording:)
        @recording = recording
      end

      attr_reader :recording
    end
  end
end
