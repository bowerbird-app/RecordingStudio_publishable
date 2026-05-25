# frozen_string_literal: true

module RecordingStudioPublishable
  module ApplicationHelper
    def publishable_head_tags(publishable_recording: nil, publishable: nil, parent_recordable: nil,
                              public_url: nil, title: nil, description: nil, canonical_url: nil,
                              social_title: nil, social_description: nil, social_image_url: nil)
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

      title ||= publishable.seo_title.presence || parent_recordable&.try(:title).presence || "Published page"
      description ||= publishable.seo_description.presence
      canonical_url ||= publishable.canonical_url.presence || public_url
      social_title ||= publishable.social_title.presence || title
      social_description ||= publishable.social_description.presence || description

      tag_rows = []
      tag_rows << tag.title(title)
      tag_rows << tag.meta(name: "description", content: description) if description.present?
      tag_rows << tag.link(rel: "canonical", href: canonical_url) if canonical_url.present?
      tag_rows << tag.meta(property: "og:type", content: "article")
      tag_rows << tag.meta(property: "og:title", content: social_title)
      tag_rows << tag.meta(property: "og:description", content: social_description) if social_description.present?
      tag_rows << tag.meta(property: "og:url", content: public_url) if public_url.present?
      tag_rows << tag.meta(property: "og:image", content: social_image_url) if social_image_url.present?
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
      path = RecordingStudioPublishable::Routing.path_for(
        publishable_recording: publishable_recording,
        publishable: publishable,
        parent_recordable_type: parent_recordable_type
      )

      return path unless respond_to?(:request) && request.respond_to?(:base_url) && request.base_url.present?

      "#{request.base_url}#{path}"
    rescue StandardError
      path
    end
  end
end
