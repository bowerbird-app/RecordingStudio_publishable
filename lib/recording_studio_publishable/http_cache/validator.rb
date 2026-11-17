# frozen_string_literal: true

require "digest"

module RecordingStudioPublishable
  module HttpCache
    module Validator
      module_function

      def for(policy, publishable)
        Digest::SHA256.hexdigest(source(policy, publishable))
      end

      def fresh?(request, validator)
        header = if_none_match(request)
        return false if header.blank? || validator.blank?

        quoted = %("#{validator}")
        header.split(",").any? { |part| token_matches?(part.strip, quoted, validator) }
      end

      def source(policy, publishable)
        fields = [policy.etag, publishable.id, publishable.status, publishable.slug]
        times = [publishable.publish_at, publishable.unpublish_at, publishable.updated_at]
        (fields + times.map { |time| stamp(time) }).join("\u001f")
      end

      def token_matches?(token, quoted, validator)
        token == "*" || token == quoted || token.delete_prefix("W/").delete("\"") == validator
      end

      def if_none_match(request)
        return request.get_header("HTTP_IF_NONE_MATCH") if request.respond_to?(:get_header)

        request.headers["If-None-Match"] if request.respond_to?(:headers)
      end

      def stamp(time)
        time.respond_to?(:utc) ? time.utc.iso8601(6) : time.to_s
      end
    end
  end
end
