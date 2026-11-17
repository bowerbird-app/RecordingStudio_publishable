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
        public_headers(headers, decision) || private_headers(headers, decision)
        headers
      end

      def public_headers(headers, decision)
        return unless decision[:public]

        strip_cookies(headers)
        headers["Cache-Control"] = decision[:cache_control]
        headers["Vary"] = decision[:vary]
        headers["ETag"] = decision[:etag]
      end

      def private_headers(headers, decision)
        headers["Cache-Control"] = PRIVATE_CACHE_CONTROL unless decision[:strip_etag]
        headers.delete("ETag")
        headers.delete("etag")
      end

      def strip_cookies(headers)
        headers.delete("Set-Cookie")
        headers.delete("set-cookie")
      end
    end
  end
end
