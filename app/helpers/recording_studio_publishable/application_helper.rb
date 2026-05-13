# frozen_string_literal: true

module RecordingStudioPublishable
  module ApplicationHelper
    def render_publishable_status_badge(publishable)
      render "recording_studio_publishable/components/status_badge", publishable: publishable
    end

    def render_publishable_quick_actions(recording)
      render "recording_studio_publishable/components/quick_actions", recording: recording
    end

    def render_publishable_summary_card(recording)
      render "recording_studio_publishable/components/summary_card", recording: recording
    end
  end
end
