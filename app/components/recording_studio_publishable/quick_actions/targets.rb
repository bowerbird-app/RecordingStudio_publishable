# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # Shared hooks for every control of one recording. Turbo `targets` uses
    # these classes so a publish updates each placement, not only the one
    # that submitted.
    module Targets
      TARGET_PARTS = {
        alert: "publishable-quick-actions-alert",
        state: "publishable-quick-actions-state",
        menu_items: "publishable-quick-actions-menu-items",
        list: "publishable-quick-actions-list"
      }.freeze

      def self.included(base)
        base.extend(ClassMethods)
      end

      # Class-level selectors. The stream template calls these.
      module ClassMethods
        def recording_class(recording)
          "publishable-quick-actions-for-#{recording.id}"
        end

        def targets_selector(recording, part)
          ".#{TARGET_PARTS.fetch(part)}.#{recording_class(recording)}"
        end
      end

      def recording_class
        self.class.recording_class(recording)
      end

      def target_classes(part)
        "#{TARGET_PARTS.fetch(part)} #{recording_class}"
      end

      def targets_selector(part)
        self.class.targets_selector(recording, part)
      end
    end
  end
end
