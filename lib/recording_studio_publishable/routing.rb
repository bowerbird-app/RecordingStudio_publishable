# frozen_string_literal: true

module RecordingStudioPublishable
  module Routing
    class << self
      def path_for(publishable_recording:, publishable: nil, parent_recordable_type: nil)
        publishable ||= publishable_recording.recordable
        parent_recordable_type ||= publishable_recording.parent_recording&.recordable_type
        template = RecordingStudioPublishable.configuration.public_path_for(parent_recordable_type)

        template
          .gsub(":uuid", publishable_recording.id.to_s)
          .gsub(":slug", publishable.slug.to_s)
      end

      def url_for(publishable_recording:, publishable: nil, parent_recordable_type: nil, host: nil, protocol: nil)
        path = path_for(
          publishable_recording: publishable_recording,
          publishable: publishable,
          parent_recordable_type: parent_recordable_type
        )

        host ||= default_url_host
        return path if host.blank?

        protocol ||= default_url_protocol
        "#{protocol}://#{host}#{path}"
      end

      private

      def default_url_host
        return unless default_url_options

        default_url_options[:host]
      rescue StandardError
        nil
      end

      def default_url_protocol
        protocol = default_url_options&.[](:protocol)
        return protocol if protocol.present?

        return unless rails_config.respond_to?(:force_ssl)

        rails_config.force_ssl ? "https" : "http"
      rescue StandardError
        "http"
      end

      def default_url_options
        return unless defined?(Rails)
        return unless Rails.application&.routes.respond_to?(:default_url_options)

        Rails.application.routes.default_url_options
      end

      def rails_config
        return unless defined?(Rails)

        Rails.application&.config
      end
    end
  end
end
