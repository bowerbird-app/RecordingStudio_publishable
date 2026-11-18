# frozen_string_literal: true

module RecordingStudioPublishable
  module PublicRead
    KEYS = %i[status slug publish_at unpublish_at public_path public_url].freeze
    ABSOLUTE_URL = %r{\Ahttps?://}i

    class << self
      def for(recording, publishable: nil, publishable_recording: nil)
        resolved_publishable = publishable || current_publishable(recording)
        resolved_child = publishable_recording || current_child(recording)
        body(recording, resolved_publishable, resolved_child)
      end

      private

      def body(recording, publishable, child)
        path, url = links(recording, publishable, child)
        {
          status: status_name(publishable),
          slug: publishable&.slug,
          publish_at: stamp(publishable, :publish_at),
          unpublish_at: stamp(publishable, :unpublish_at),
          public_path: path,
          public_url: url
        }
      end

      def links(recording, publishable, child)
        return [nil, nil] unless live?(recording, publishable)

        route = route_for(recording, publishable, child)
        [Routing.path_for(**route).presence, absolute(Routing.url_for(**route))]
      end

      def live?(recording, publishable)
        return false unless publishable&.currently_published?
        return false unless recording.respond_to?(:currently_published?)

        recording.currently_published?
      end

      def route_for(recording, publishable, child)
        {
          publishable_recording: child,
          publishable: publishable,
          parent_recordable_type: recording.recordable_type
        }
      end

      def absolute(url)
        value = url.to_s
        value if value.match?(ABSOLUTE_URL)
      end

      def status_name(publishable)
        return "draft" unless publishable
        return "scheduled" if publishable.scheduled_for_future?
        return "published" if publishable.published_state?

        "draft"
      end

      def stamp(publishable, name)
        publishable&.public_send(name)&.iso8601
      end

      def current_publishable(recording)
        return unless recording.respond_to?(:current_publishable)

        recording.current_publishable
      end

      def current_child(recording)
        return unless recording.respond_to?(:publishable_child_recording)

        recording.publishable_child_recording
      end
    end
  end
end
