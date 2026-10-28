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
          Copy.t("status.scheduled")
        elsif publishable.published_state?
          Copy.t("status.published")
        else
          Copy.t("status.draft")
        end
      end
    end
  end
end
