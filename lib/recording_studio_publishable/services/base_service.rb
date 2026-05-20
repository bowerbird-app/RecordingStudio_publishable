# frozen_string_literal: true

module RecordingStudioPublishable
  module Services
    class BaseService < ::RecordingStudio::Services::BaseService
      private

      # Keep addon-level hooks so existing integrations continue to work.
      def run_before_hooks
        return unless hooks_enabled?

        RecordingStudioPublishable::Hooks.run(:before_service, self.class, service_args)
      end

      def run_after_hooks(result)
        return unless hooks_enabled?

        RecordingStudioPublishable::Hooks.run(:after_service, self.class, result)
      end

      def run_with_around_hooks
        if hooks_enabled? && RecordingStudioPublishable.configuration.hooks.registered?(:around_service)
          RecordingStudioPublishable::Hooks.run_around(:around_service, self) { perform }
        else
          perform
        end
      end

      def hooks_enabled?
        defined?(RecordingStudioPublishable) &&
          RecordingStudioPublishable.respond_to?(:configuration) &&
          RecordingStudioPublishable.configuration.respond_to?(:hooks)
      end
    end
  end
end
