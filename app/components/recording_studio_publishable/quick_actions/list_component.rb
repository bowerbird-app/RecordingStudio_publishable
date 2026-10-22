# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # Rows only, for a menu or the phone hamburger. No second dropdown.
    class ListComponent < Component
      def renderer_name
        "list"
      end
    end
  end
end
