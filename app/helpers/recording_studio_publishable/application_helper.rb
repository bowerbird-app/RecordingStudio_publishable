# frozen_string_literal: true

module RecordingStudioPublishable
  module ApplicationHelper
    def render_publishable_status_badge(publishable)
      render RecordingStudioPublishable::StatusBadge::Component.new(publishable: publishable)
    end

    def render_publishable_quick_actions(recording)
      render RecordingStudioPublishable::QuickActions::Component.new(recording: recording)
    end

  end
end
