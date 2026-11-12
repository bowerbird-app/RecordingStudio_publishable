# frozen_string_literal: true

module RecordingStudioPublishable
  class ShareButtonUrl
    ABSOLUTE_URL = %r{\Ahttps?://}i

    class << self
      def absolute(recording, base_url:)
        return unless live?(recording)

        raw = public_path(recording)
        return if raw.blank?

        url = absolute_from(recording, raw.to_s, base_url)
        url if absolute?(url)
      end

      private

      def live?(recording)
        recording.respond_to?(:currently_published?) && recording.currently_published?
      end

      def public_path(recording)
        return unless recording.respond_to?(:publishable_public_path)

        recording.publishable_public_path
      end

      def absolute_from(recording, raw, base_url)
        return raw if absolute?(raw)
        return join_base(base_url, raw) if base_url.present?

        hosted_url(recording)
      end

      def absolute?(url)
        url.to_s.match?(ABSOLUTE_URL)
      end

      def hosted_url(recording)
        return unless recording.respond_to?(:publishable_public_url)

        host, protocol = configured_origin
        return if host.blank?

        recording.publishable_public_url(host: host, protocol: protocol)
      end

      def configured_origin
        options = default_url_options
        [option(options, :host).presence, option(options, :protocol).presence]
      end

      def default_url_options
        return {} unless defined?(Rails)
        return {} unless Rails.application&.routes.respond_to?(:default_url_options)

        Rails.application.routes.default_url_options || {}
      rescue StandardError
        {}
      end

      def option(options, name)
        options[name] || options[name.to_s]
      end

      def join_base(base, path)
        suffix = path.start_with?("/") ? path : "/#{path}"
        "#{base.to_s.sub(%r{/+\z}, '')}#{suffix}"
      end
    end
  end
end
