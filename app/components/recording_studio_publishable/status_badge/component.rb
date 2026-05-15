# frozen_string_literal: true

module RecordingStudioPublishable
  module StatusBadge
    class Component < ViewComponent::Base
      def initialize(publishable:)
        @publishable = publishable
      end

      attr_reader :publishable

      def badge_style
        if publishable.currently_published?
          :success
        elsif publishable.scheduled_for_future?
          :warning
        elsif publishable.unpublished?
          :error
        else
          :info
        end
      end

      def badge_text
        publishable.currently_published? ? "Published" : publishable.status.humanize
      end
    end
  end
end
