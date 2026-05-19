# frozen_string_literal: true

module RecordingStudioPublishable
  module StatusBadge
    class Component < ViewComponent::Base
      def initialize(publishable:)
        @publishable = publishable
      end

      attr_reader :publishable

      def badge_style
        if publishable.published_state?
          :success
        else
          :info
        end
      end

      def badge_text
        publishable.published_state? ? "Published" : "Draft"
      end
    end
  end
end
