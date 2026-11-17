# frozen_string_literal: true

module RecordingStudioPublishable
  module HttpCache
    NONCE_HEADER = "action_dispatch.content_security_policy_nonce"

    class << self
      def drop_nonce_content_security_policy!(controller, decision)
        request = controller.request
        return decision unless nonce_content_security_policy?(request)

        clear_nonce_content_security_policy!(request)
        decision.merge(drop_nonce_csp: true)
      end

      private

      def nonce_content_security_policy?(request)
        return false unless request.respond_to?(:get_header)

        nonce_generator?(request) || request.get_header(NONCE_HEADER).present?
      end

      def nonce_generator?(request)
        return false unless request.respond_to?(:content_security_policy_nonce_generator)

        request.content_security_policy_nonce_generator.present?
      end

      def clear_nonce_content_security_policy!(request)
        clear_content_security_policy!(request)
        clear_nonce_generator!(request)
        request.delete_header(NONCE_HEADER) if request.respond_to?(:delete_header)
      end

      def clear_content_security_policy!(request)
        return unless request.respond_to?(:content_security_policy=)

        request.content_security_policy = nil
      end

      def clear_nonce_generator!(request)
        if request.respond_to?(:content_security_policy_nonce_generator=)
          request.content_security_policy_nonce_generator = nil
        end
        return unless request.respond_to?(:content_security_policy_nonce_directives=)

        request.content_security_policy_nonce_directives = nil
      end
    end
  end
end
