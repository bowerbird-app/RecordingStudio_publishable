# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # The collapsed publish section. Turbo replaces this whole piece, header included.
    class ListBodyComponent < ViewComponent::Base
      def initialize(presenter:)
        @presenter = presenter
      end

      attr_reader :presenter
    end
  end
end
