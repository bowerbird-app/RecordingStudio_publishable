# frozen_string_literal: true

module RecordingStudioPublishable
  module EditButton
    class Component < ViewComponent::Base
      def initialize(publishable:, label: "Edit", status: nil, **options)
        @publishable = publishable
        @label = label
        @status = status
        @options = options
      end

      def edit_path
        helpers.edit_recording_studio_publishable_publishable_path(@publishable)
      end
    end
  end
end
