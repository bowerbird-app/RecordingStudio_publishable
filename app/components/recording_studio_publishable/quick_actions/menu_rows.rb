# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # The rows both renderers show for one publish state.
    class MenuRows
      def initialize(presenter)
        @presenter = presenter
      end

      def to_a
        action_rows + [
          page_row,
          divider_row,
          job_row(:search, "magnifying-glass", :seo),
          job_row(:social, "share", :social)
        ]
      end

      private

      attr_reader :presenter

      def action_rows
        actions = presenter.appearance.menu_actions(
          presenter.closed_state,
          schedule_enabled: presenter.schedule_enabled?
        )
        actions.map { |action_name| action_row(action_name) }
      end

      def action_row(action_name)
        action = Catalog::ACTIONS.fetch(action_name)
        text = Copy.t(schedule_label(action_name))
        return form_row(text, action[:icon], transition_path(action[:transition])) if action[:transition]

        link_row(text, action[:icon], job_path(:schedule))
      end

      def schedule_label(action_name)
        return "actions.change_schedule" if action_name == :schedule && presenter.closed_state == :scheduled

        Catalog::ACTIONS.fetch(action_name)[:text_key]
      end

      def page_row
        link = RecordingStudioPublishable::PageLink.for(
          recording: presenter.recording,
          preview_href: job_path(:preview)
        )
        link_row(link.text, link.icon, link.href, target: "_blank", rel: "noopener noreferrer", data: { turbo: false })
      end

      def job_row(route_key, icon_name, label_key)
        link_row(Copy.t("actions.#{label_key}"), icon_name, job_path(route_key))
      end

      def form_row(text, icon_name, href)
        Catalog::Row.new(kind: :form, text: text, icon: icon_name, href: href, target: nil, rel: nil, data: nil)
      end

      def link_row(text, icon_name, href, **extra)
        Catalog::Row.new(
          kind: :link,
          text: text,
          icon: icon_name,
          href: href,
          target: extra[:target],
          rel: extra[:rel],
          data: extra[:data]
        )
      end

      def divider_row
        Catalog::Row.new(kind: :divider, text: nil, icon: nil, href: nil, target: nil, rel: nil, data: nil)
      end

      def transition_path(transition)
        routes.transition_recording_publishable_path(recording_id: presenter.recording.id, transition: transition)
      end

      def job_path(key)
        routes.public_send("#{key}_recording_publishable_path", recording_id: presenter.recording.id)
      end

      def routes
        presenter.routes.recording_studio_publishable
      end
    end
  end
end
