# frozen_string_literal: true

require "erb"
require "i18n"
require "active_support/core_ext/string/output_safety"

module RecordingStudioPublishable
  # Rails I18n lookups for Publishable user-facing copy. Every call passes
  # `default:` English (from ENGLISH or an explicit caller default) so a host
  # locale without a fallback never shows "translation missing".
  module Copy
    PREFIX = "recording_studio.publishable"
    UNSET = Object.new.freeze

    # Byte-identical English defaults matching config/locales/en.yml.
    # rubocop:disable Style/FormatStringToken -- I18n interpolation tokens
    ENGLISH = {
      "layout.title" => "Recording Studio Publishable",
      "hub.title" => "Publish",
      "hub.back" => "Home",
      "hub.close" => "Close",
      "success.title" => "Published!",
      "success.copy_link" => "Copy link",
      "success.copied" => "Copied",
      "success.view" => "View",
      "success.copy_prompt" => "Copy link",
      "jobs.schedule.title" => "Schedule",
      "jobs.schedule.subtitle" => "Pick when this goes live.",
      "jobs.schedule.notice" => "Times saved.",
      "jobs.search.title" => "SEO",
      "jobs.search.subtitle" => "How this shows up in search.",
      "jobs.search.notice" => "SEO saved.",
      "jobs.social.title" => "Social",
      "jobs.social.subtitle" => "How this looks when someone shares it.",
      "jobs.social.notice" => "Social preview saved.",
      "nav.back" => "Publish",
      "nav.close" => "Close",
      "actions.publish_now" => "Publish now",
      "actions.schedule" => "Schedule",
      "actions.change_schedule" => "Change schedule",
      "actions.unpublish" => "Unpublish",
      "actions.seo" => "SEO",
      "actions.social" => "Social",
      "status.draft" => "Draft",
      "status.scheduled" => "Scheduled",
      "status.published" => "Published",
      "page_link.view" => "View",
      "page_link.view_subtitle" => "See it live.",
      "page_link.preview" => "Preview",
      "page_link.preview_subtitle" => "See it before it goes live.",
      "preview.badge" => "Preview",
      "fallbacks.published_page" => "Published page",
      "summary.title" => "Summary",
      "summary.subtitle" => "Current public metadata for this recording.",
      "summary.slug" => "Slug:",
      "summary.canonical_path" => "Canonical path:",
      "summary.publish_window" => "Publish window:",
      "summary.always_available" => "Always available when published",
      "summary.seo_title" => "SEO title:",
      "summary.uses_parent_title" => "Uses parent recording title",
      "summary.empty" => "A publishable child recording will be created the first time someone opens the edit screen.",
      "published.fallback_subtitle" => "Published from the parent recording's current recordable.",
      "published.parent_recordable" => "Parent recordable:",
      "published.current_title" => "Current title:",
      "published.canonical_url" => "Canonical URL:",
      "published.social_card" => "Social card:",
      "edit_button.label" => "Edit",
      "form.save" => "Save",
      "form.publish_at" => "Publish at",
      "form.unpublish_at" => "Unpublish at",
      "form.time_zone" => "Time zone",
      "form.time_zone_placeholder" => "Select a time zone",
      "form.never" => "Never",
      "form.slug" => "Slug",
      "form.title" => "Title",
      "form.title_help" => "Leave blank to use the page name.",
      "form.description" => "Description",
      "form.description_placeholder" => "A short line for search results",
      "form.description_help" => "The line under the title in search results.",
      "form.advanced" => "Advanced",
      "form.noindex" => "noindex",
      "form.noindex_help" => "Ask search engines not to index this page. It stays live.",
      "form.canonical_url" => "Canonical URL",
      "form.canonical_placeholder" => "https://",
      "form.canonical_help" => "The preferred URL for this page. Leave blank to use this page's URL.",
      "form.social_title" => "Social title",
      "form.social_description" => "Social description",
      "form.social_description_placeholder" => "Description shown in social previews",
      "form.social_image_alt" => "Social image",
      "form.upload_photo" => "Upload Photo",
      "form.select_social_image" => "Select social image",
      "form.search_social_images" => "Search social images",
      "form.no_images" => "No images here yet.",
      "form.selected_image" => "Selected image",
      "form.replace_image" => "Click to replace image.",
      "form.character_count" => "%{count} / %{limit} characters",
      "flashes.save_failed" => "Could not save that.",
      "flashes.update_failed" => "Could not update this page.",
      "flashes.not_found" => "Publishable not found",
      "flashes.status_updated" => "Publishable status updated",
      "flashes.published_just_now" => "Published just now",
      "flashes.scheduled_in" => "Scheduled to publish in %{distance}",
      "flashes.published_ago" => "Published %{distance} ago",
      "attributes.slug" => "Slug",
      "attributes.status" => "Status",
      "attributes.publish_at" => "Publish at",
      "attributes.unpublish_at" => "Unpublish at",
      "attributes.time_zone" => "Time zone",
      "attributes.seo_title" => "Title",
      "attributes.seo_description" => "Description",
      "attributes.canonical_url" => "Canonical URL",
      "attributes.meta_robots" => "Search listing",
      "attributes.social_title" => "Social title",
      "attributes.social_description" => "Social description",
      "attributes.social_image_attachment_recording_id" => "Social image",
      "errors.attribute_invalid" => "%{attribute} is invalid",
      "errors.social_image_invalid" => "Social image is invalid",
      "errors.unknown_transition" => "Unknown publishable transition",
      "errors.parent_required" => "Parent recording is required",
      "errors.cannot_own_children" => "Publishable recordings cannot own publishable children",
      "errors.recording_not_found" => "Publishable recording was not found",
      "errors.not_public" => "Publishable recording is not currently public",
      "errors.slug_stale" => "Publishable slug is stale",
      "errors.slug_format" => "must use URL-safe lowercase slug segments",
      "errors.unpublish_after_publish" => "must be later than publish at"
    }.freeze
    # rubocop:enable Style/FormatStringToken

    module_function

    def t(key, **options)
      full_key = "#{PREFIX}.#{key}"
      english = ENGLISH[key.to_s]
      options = { default: english }.merge(options) if english && !options.key?(:default)

      return I18n.t(full_key, **options) unless key.to_s.end_with?("_html")

      escaped = options.transform_values { |value| value.is_a?(String) ? ERB::Util.html_escape(value) : value }
      I18n.t(full_key, **escaped).to_s.html_safe
    end

    def l(object, **)
      I18n.l(object, **)
    end

    def provided?(value)
      !value.equal?(UNSET)
    end

    def value(override, key, **)
      provided?(override) ? override : t(key, **)
    end

    # Host config that still matches the English default follows the locale.
    # A different string (including blank after presence) is host copy and wins.
    def defaulted(value, default, key, **)
      return t(key, **) if value.nil? || value == default

      value
    end

    def attribute_name(attribute)
      name = attribute.to_s
      t("attributes.#{name}", default: name.humanize)
    end

    def attribute_invalid(attribute)
      t("errors.attribute_invalid", attribute: attribute_name(attribute))
    end
  end
end
