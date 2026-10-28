# frozen_string_literal: true

module RecordingStudioPublishable
  module HeadTagsInternals
    DEFAULT_SOCIAL_IMAGE_WIDTH = 1200
    DEFAULT_SOCIAL_IMAGE_HEIGHT = 630
    DEFAULT_SOCIAL_IMAGE_VARIANT = :social_share

    private

    def head_tag_rows(seo_enabled:, description:, canonical_url:, robots:, social_title:, social_description:,
                      public_url:, social_image_url:, social_image_width:, social_image_height:)
      tag_rows = []
      if seo_enabled
        tag_rows << tag.meta(name: "description", content: description) if description.present?
        tag_rows << tag.link(rel: "canonical", href: canonical_url) if canonical_url.present?
      end
      tag_rows << tag.meta(name: "robots", content: robots) if robots.present?
      tag_rows << tag.meta(property: "og:type", content: "article")
      tag_rows << tag.meta(property: "og:title", content: social_title)
      tag_rows << tag.meta(property: "og:description", content: social_description) if social_description.present?
      tag_rows << tag.meta(property: "og:url", content: public_url) if public_url.present?
      tag_rows << tag.meta(property: "og:image", content: social_image_url) if social_image_url.present?
      tag_rows << tag.meta(property: "og:image:width", content: social_image_width) if social_image_width.present?
      tag_rows << tag.meta(property: "og:image:height", content: social_image_height) if social_image_height.present?
      tag_rows << tag.meta(name: "twitter:card", content: social_image_url.present? ? "summary_large_image" : "summary")
      tag_rows << tag.meta(name: "twitter:title", content: social_title)
      tag_rows << tag.meta(name: "twitter:description", content: social_description) if social_description.present?
      tag_rows << tag.meta(name: "twitter:image", content: social_image_url) if social_image_url.present?
      tag_rows
    end

    def publishable_public_url(publishable_recording:, publishable:, parent_recordable_type: nil)
      parent_recordable = publishable_recording&.parent_recording&.recordable
      path = parent_recordable.respond_to?(:published_url) ? parent_recordable.published_url : nil
      path ||= RecordingStudioPublishable::Routing.url_for(
        publishable_recording: publishable_recording,
        publishable: publishable,
        parent_recordable_type: parent_recordable_type || publishable_recording&.parent_recording&.recordable_type
      )

      return path if path.blank?

      return path unless respond_to?(:request) && request.respond_to?(:base_url) && request.base_url.present?

      "#{request.base_url}#{path}"
    rescue StandardError
      path
    end

    def resolved_social_image_url(publishable:)
      return unless publishable.respond_to?(:social_image_attached?) && publishable.social_image_attached?

      attachment_recording = publishable.try(:social_image_attachment_recording)
      return if attachment_recording.blank?
      return unless respond_to?(:recording_studio_attachable)

      attachable_routes = recording_studio_attachable
      return unless attachable_routes.respond_to?(:attachment_preview_file_path)

      path = attachable_routes.attachment_preview_file_path(
        attachment_recording,
        variant_name: DEFAULT_SOCIAL_IMAGE_VARIANT
      )

      absolute_url_for(path)
    rescue StandardError
      nil
    end

    def absolute_url_for(path)
      return if path.blank?
      return path if path.to_s.match?(%r{\Ahttps?://}i)

      return path unless respond_to?(:request) && request.respond_to?(:base_url) && request.base_url.present?

      "#{request.base_url}#{path}"
    end

    def seo_enabled_for_publishable?(publishable_recording:)
      recordable_type = publishable_recording&.parent_recording&.recordable_type
      return true if recordable_type.blank?

      RecordingStudioPublishable.configuration.seo_enabled_for(recordable_type)
    rescue StandardError
      true
    end

    def document_title_for(publishable:, parent_recordable:)
      publishable.try(:seo_title).presence || parent_recordable&.try(:title).presence ||
        publishable.try(:social_title).presence || Copy.t("fallbacks.published_page")
    end

    def canonical_url_for(publishable:, public_url:)
      publishable.try(:canonical_url).presence || public_url.presence
    end

    def robots_content_for(publishable)
      return publishable.robots_value if publishable.respond_to?(:robots_value)

      publishable.try(:meta_robots).to_s.strip.presence ||
        RecordingStudioPublishable::Publishable::DEFAULT_ROBOTS
    end
  end
end
