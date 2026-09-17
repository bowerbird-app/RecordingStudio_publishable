# frozen_string_literal: true

module RecordingStudioPublishable
  class PageLink
    Link = Data.define(:text, :subtitle, :icon, :href)

    def self.for(recording:, preview_href:)
      new(recording: recording, preview_href: preview_href).link
    end

    def initialize(recording:, preview_href:)
      @recording = recording
      @preview_href = preview_href
    end

    def link
      href = live_href
      return view_link(href) if href.present?

      preview_link
    end

    private

    def live_href
      return unless published?

      RecordingStudioPublishable::Routing.path_for(
        publishable_recording: @recording.publishable_child_recording,
        parent_recordable_type: @recording.recordable_type
      )
    end

    def published?
      publishable = @recording.current_publishable
      publishable.present? && publishable.published_state? && !publishable.scheduled_for_future?
    end

    def view_link(href)
      Link.new(
        text: "View",
        subtitle: "See it live.",
        icon: "arrow-top-right-on-square",
        href: href
      )
    end

    def preview_link
      Link.new(
        text: "Preview",
        subtitle: "See it before it goes live.",
        icon: "eye",
        href: @preview_href
      )
    end
  end
end
