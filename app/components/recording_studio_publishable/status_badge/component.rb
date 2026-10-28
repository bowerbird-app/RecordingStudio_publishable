# frozen_string_literal: true

module RecordingStudioPublishable
  module StatusBadge
    class Component < ViewComponent::Base
      def initialize(publishable:)
        super()
        @publishable = publishable
      end

      attr_reader :publishable

      def badge_style
        Status.badge_style(publishable)
      end

      def badge_text
        Status.label(publishable)
      end
    end
  end
end
