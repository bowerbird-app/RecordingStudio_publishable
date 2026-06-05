# frozen_string_literal: true

module RecordingStudioPublishable
  module StatusBadge
    class Component < ViewComponent::Base
      def initialize(publishable:)
        @publishable = publishable
      end

      attr_reader :publishable

      def badge_style
        if publishable.scheduled_for_future?
          :warning
        elsif publishable.published_state?
          :success
        else
          :info
        end
      end

      def badge_text
        if publishable.scheduled_for_future?
          "Scheduled"
        elsif publishable.published_state?
          "Published"
        else
          "Draft"
        end
      end
    end
  end
end
