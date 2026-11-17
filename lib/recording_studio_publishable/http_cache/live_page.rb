# frozen_string_literal: true

module RecordingStudioPublishable
  module HttpCache
    class << self
      private

      def cache_live_page(controller)
        publishable = controller.instance_variable_get(:@publishable)
        return unless live_publishable?(publishable)

        policy = fetch_policy(controller)
        return note_private(controller) unless public_policy?(policy)

        send_not_modified(controller, policy, publishable)
      end

      def note_private(controller)
        deny!(controller)
        nil
      end

      def send_not_modified(controller, policy, publishable)
        validator = Validator.for(policy, publishable)
        decision = remember_public(controller, policy, validator)
        return unless Validator.fresh?(controller.request, validator)

        controller.head :not_modified
        write_public!(controller.response, decision)
        :not_modified
      end

      def remember_public(controller, policy, validator)
        controller.instance_variable_set(:@publishable_http_cache, policy)
        decision = drop_nonce_content_security_policy!(controller, public_decision(policy, validator))
        remember!(controller.request, **decision)
        write_public!(controller.response, decision)
        skip_session!(controller.request)
        decision
      end

      def live?(controller)
        live_publishable?(controller.instance_variable_get(:@publishable))
      end

      def live_publishable?(publishable)
        publishable.respond_to?(:currently_published?) && publishable.currently_published?
      end

      def public_policy?(policy)
        policy.respond_to?(:public?) && policy.public?
      end

      def policy_for(recordable, request)
        return unless recordable.respond_to?(:publishable_http_cache)

        recordable.publishable_http_cache(request)
      end

      def public_decision(policy, validator)
        {
          public: true,
          cache_control: policy.cache_control,
          vary: policy.vary_header,
          etag: %("#{validator}")
        }
      end

      def write_public!(response, decision)
        response.set_header("Cache-Control", decision[:cache_control])
        response.set_header("Vary", decision[:vary])
        response.set_header("ETag", decision[:etag])
      end

      def remember!(request, **decision)
        return unless request.respond_to?(:env)

        request.env[ENV_KEY] = decision
      end

      def decision_for(request)
        return unless request.respond_to?(:env)

        request.env[ENV_KEY]
      end

      def skip_session!(request)
        options = request.session_options if request.respond_to?(:session_options)
        options[:skip] = true if options
      end
    end
  end
end
