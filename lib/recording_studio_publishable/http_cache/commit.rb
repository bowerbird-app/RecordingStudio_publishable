# frozen_string_literal: true

module RecordingStudioPublishable
  module HttpCache
    # Runs outside the cookie middleware so a public response can drop
    # Set-Cookie after the session store and host filters commit.
    class Commit
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)
        decision = env[ENV_KEY]
        return [status, headers, body] if decision.blank?

        [status, write(headers, decision), body]
      end

      private

      def write(headers, decision)
        headers = Rack::Headers[headers] if defined?(Rack::Headers)
        if decision[:public]
          public_headers(headers, decision)
        else
          private_headers(headers)
        end
        headers
      end

      def public_headers(headers, decision)
        strip_cookies(headers)
        strip_nonce_csp(headers, decision)
        headers["Cache-Control"] = decision[:cache_control]
        headers["Vary"] = decision[:vary]
        headers["ETag"] = decision[:etag]
      end

      def private_headers(headers)
        headers["Cache-Control"] = PRIVATE_CACHE_CONTROL
        headers.delete("ETag")
        headers.delete("etag")
      end

      def strip_nonce_csp(headers, decision)
        return unless decision[:drop_nonce_csp] || nonce_csp_header?(headers)

        headers.delete("Content-Security-Policy")
        headers.delete("Content-Security-Policy-Report-Only")
      end

      def nonce_csp_header?(headers)
        [headers["Content-Security-Policy"], headers["Content-Security-Policy-Report-Only"]].any? do |value|
          value.to_s.include?("nonce-")
        end
      end

      def strip_cookies(headers)
        headers.delete("Set-Cookie")
        headers.delete("set-cookie")
      end
    end
  end
end
