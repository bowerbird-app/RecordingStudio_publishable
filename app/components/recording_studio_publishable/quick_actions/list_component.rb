# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # Publish rows inside a host dropdown, collapsed to the current state.
    class ListComponent < Component
      def renderer_name
        "list"
      end

      def list_classes
        ClassNames.merge("flex w-full flex-col", presenter.target_classes(:list))
      end
    end
  end
end
