# frozen_string_literal: true

require_relative "copy_helper"
require_relative "head_tags_helper"

module RecordingStudioPublishable
  module ApplicationHelper
    include CopyHelper
    include HeadTagsHelper

    def render_publishable_status_badge(publishable)
      render RecordingStudioPublishable::StatusBadge::Component.new(publishable: publishable)
    end

    def publishable_quick_actions_for(recording, **)
      RecordingStudioPublishable::QuickActions::Component.new(recording: recording, **)
    end

    def publishable_quick_actions_list_for(recording, **)
      RecordingStudioPublishable::QuickActions::ListComponent.new(recording: recording, **)
    end

    def render_publishable_quick_actions(recording, **)
      render publishable_quick_actions_for(recording, **)
    end

    def render_publishable_quick_actions_list(recording, **)
      render publishable_quick_actions_list_for(recording, **)
    end

    def publishable_preview?
      return true if instance_variable_defined?(:@publishable_preview) && @publishable_preview
      return false unless defined?(controller) && controller.respond_to?(:action_name)

      controller.is_a?(RecordingStudioPublishable::PublishablesController) && controller.action_name == "preview"
    end

    def publishable_hides_host_chrome?
      return true if defined?(controller) && controller.is_a?(RecordingStudioPublishable::PublishedController)

      publishable_preview?
    end

    def publishable_management_nav(title:, subtitle: nil, back_href: nil, back_tooltip: nil,
                                   anchor_href: nil, anchor_tooltip: nil)
      content_for(:title, title)
      content_for(:subtitle, subtitle) if subtitle.present?
      return unless respond_to?(:flat_pack_page_nav)

      flat_pack_page_nav(round: true, style: :default, back_href: back_href, back_tooltip: back_tooltip,
                         anchor_href: anchor_href, anchor_tooltip: anchor_tooltip)
    end

    def publishable_hides_page_nav_right?
      return true if publishable_hides_host_chrome?
      return false unless defined?(controller)

      controller.is_a?(RecordingStudioPublishable::PublishablesController)
    end

    def publishable_preview_badge
      return unless publishable_preview?

      render FlatPack::Badge::Component.new(text: Copy.t("preview.badge"), style: :warning, size: :sm)
    end
  end
end
