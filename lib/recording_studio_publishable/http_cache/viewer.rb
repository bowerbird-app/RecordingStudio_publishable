# frozen_string_literal: true

module RecordingStudioPublishable
  module HttpCache
    POLICY_KEY = "recording_studio_publishable.http_cache_policy"
    POLICY_READY_KEY = "recording_studio_publishable.http_cache_policy_ready"

    class << self
      # Loads the session and copies the signed-in user onto Current.actor
      # when that attribute is still blank. The hook reads Current.actor.
      def prepare_viewer!(controller)
        load_session!(controller)
        assign_current_actor(resolved_actor(controller))
      end

      def fetch_policy(controller)
        env = policy_env(controller)
        return unless env
        return env[POLICY_KEY] if env[POLICY_READY_KEY]

        prepare_viewer!(controller)
        store_policy(env, policy_after_published_check(controller))
      end

      private

      def policy_env(controller)
        request = controller.request if controller.respond_to?(:request)
        return unless request.respond_to?(:env)

        request.env
      end

      def store_policy(env, policy)
        env[POLICY_READY_KEY] = true
        env[POLICY_KEY] = policy
      end

      def load_session!(controller)
        controller.session if controller.respond_to?(:session)
      rescue StandardError
        nil
      end

      def resolved_actor(controller)
        RecordingStudioPublishable.configuration.actor_for(controller: controller)
      rescue StandardError
        nil
      end

      def assign_current_actor(actor)
        return if actor.blank?
        return unless defined?(Current) && Current.respond_to?(:actor=)
        return if Current.actor.present?

        Current.actor = actor
      end

      def policy_after_published_check(controller)
        recordable = parent_recordable_for(controller)
        return unless recordable

        policy_for(recordable, controller.request)
      end

      def parent_recordable_for(controller)
        assigned = controller.instance_variable_get(:@parent_recordable)
        return assigned if assigned && live_assigned?(controller)

        recording = publishable_recording_for(controller)
        return unless live_publishable?(recording&.recordable)

        recording.parent_recording&.recordable
      end

      def live_assigned?(controller)
        live_publishable?(controller.instance_variable_get(:@publishable))
      end

      def publishable_recording_for(controller)
        assigned = controller.instance_variable_get(:@publishable_recording)
        return assigned if assigned
        return unless controller.respond_to?(:find_publishable_recording, true)

        controller.send(:find_publishable_recording)
      end
    end
  end
end
