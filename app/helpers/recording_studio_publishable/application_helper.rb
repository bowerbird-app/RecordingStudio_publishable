# frozen_string_literal: true

module RecordingStudioPublishable
  module ApplicationHelper
    DEFAULT_SOCIAL_IMAGE_WIDTH = 1200
    DEFAULT_SOCIAL_IMAGE_HEIGHT = 630
    DEFAULT_SOCIAL_IMAGE_VARIANT = :social_share

    def publishable_head_tags(publishable_recording: nil, publishable: nil, parent_recordable: nil,
                              public_url: nil, title: nil, description: nil, canonical_url: nil,
                              social_title: nil, social_description: nil, social_image_url: nil,
                              social_image_width: nil, social_image_height: nil)
      publishable_recording ||= instance_variable_defined?(:@publishable_recording) ? @publishable_recording : nil
      publishable ||= instance_variable_defined?(:@publishable) ? @publishable : nil
      parent_recordable ||= instance_variable_defined?(:@parent_recordable) ? @parent_recordable : nil
      parent_recordable ||= publishable_recording&.parent_recording&.recordable

      return "".html_safe if publishable.blank? || publishable_recording.blank? || !publishable.currently_published?

      public_url ||= publishable_public_url(
        publishable_recording: publishable_recording,
        publishable: publishable,
        parent_recordable_type: publishable_recording.parent_recording&.recordable_type
      )

      seo_enabled = seo_enabled_for_publishable?(publishable_recording: publishable_recording)

      if seo_enabled
        title ||= publishable.seo_title.presence || parent_recordable&.try(:title).presence || "Published page"
        description ||= publishable.seo_description.presence
        canonical_url ||= publishable.canonical_url.presence || public_url
      end

      social_title ||= publishable.social_title.presence || parent_recordable&.try(:title).presence || "Published page"
      social_description ||= publishable.social_description.presence
      social_image_url ||= resolved_social_image_url(publishable: publishable)

      if social_image_url.present?
        social_image_width ||= DEFAULT_SOCIAL_IMAGE_WIDTH
        social_image_height ||= DEFAULT_SOCIAL_IMAGE_HEIGHT
      end

      tag_rows = []
      if seo_enabled
        tag_rows << tag.title(title) if title.present?
        tag_rows << tag.meta(name: "description", content: description) if description.present?
        tag_rows << tag.link(rel: "canonical", href: canonical_url) if canonical_url.present?
      end
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

      safe_join(tag_rows, "\n")
    end

    def render_publishable_status_badge(publishable)
      render RecordingStudioPublishable::StatusBadge::Component.new(publishable: publishable)
    end

    def render_publishable_quick_actions(recording)
      render RecordingStudioPublishable::QuickActions::Component.new(recording: recording)
    end

    private

    def publishable_public_url(publishable_recording:, publishable:, parent_recordable_type: nil)
      parent_recordable = publishable_recording&.parent_recording&.recordable
      path = parent_recordable.respond_to?(:published_url) ? parent_recordable.published_url : nil

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
  end
end
