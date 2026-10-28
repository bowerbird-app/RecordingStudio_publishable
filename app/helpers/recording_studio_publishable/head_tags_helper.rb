# frozen_string_literal: true

require_relative "head_tags_internals"

module RecordingStudioPublishable
  module HeadTagsHelper
    include HeadTagsInternals

    def publishable_head_tags(publishable_recording: nil, publishable: nil, parent_recordable: nil,
                              public_url: nil, description: nil, canonical_url: nil,
                              social_title: nil, social_description: nil, social_image_url: nil,
                              social_image_width: nil, social_image_height: nil)
      publishable_recording ||= instance_variable_defined?(:@publishable_recording) ? @publishable_recording : nil
      publishable ||= instance_variable_defined?(:@publishable) ? @publishable : nil
      parent_recordable ||= instance_variable_defined?(:@parent_recordable) ? @parent_recordable : nil
      parent_recordable ||= publishable_recording&.parent_recording&.recordable

      return "".html_safe if publishable.blank? || publishable_recording.blank?

      return tag.meta(name: "robots", content: "noindex,nofollow") if publishable_preview?

      return "".html_safe unless publishable.currently_published?

      public_url ||= publishable_public_url(
        publishable_recording: publishable_recording,
        publishable: publishable,
        parent_recordable_type: publishable_recording.parent_recording&.recordable_type
      )

      seo_enabled = seo_enabled_for_publishable?(publishable_recording: publishable_recording)
      robots = robots_content_for(publishable)

      if seo_enabled
        description ||= publishable.seo_description.presence
        canonical_url ||= canonical_url_for(publishable: publishable, public_url: public_url)
      end

      social_title ||= publishable.social_title.presence || parent_recordable&.try(:title).presence ||
                       Copy.t("fallbacks.published_page")
      social_description ||= publishable.social_description.presence
      social_image_url ||= resolved_social_image_url(publishable: publishable)

      if social_image_url.present?
        social_image_width ||= DEFAULT_SOCIAL_IMAGE_WIDTH
        social_image_height ||= DEFAULT_SOCIAL_IMAGE_HEIGHT
      end

      safe_join(
        head_tag_rows(
          seo_enabled: seo_enabled,
          description: description,
          canonical_url: canonical_url,
          robots: robots,
          social_title: social_title,
          social_description: social_description,
          public_url: public_url,
          social_image_url: social_image_url,
          social_image_width: social_image_width,
          social_image_height: social_image_height
        ),
        "\n"
      )
    end

    def publishable_document_title(publishable_recording: nil, publishable: nil, parent_recordable: nil, title: nil)
      publishable_recording ||= instance_variable_defined?(:@publishable_recording) ? @publishable_recording : nil
      publishable ||= instance_variable_defined?(:@publishable) ? @publishable : nil
      parent_recordable ||= instance_variable_defined?(:@parent_recordable) ? @parent_recordable : nil
      parent_recordable ||= publishable_recording&.parent_recording&.recordable

      return if publishable.blank? || publishable_recording.blank?
      return unless publishable.currently_published? || publishable_preview?

      title.presence || document_title_for(publishable: publishable, parent_recordable: parent_recordable)
    end
  end
end
