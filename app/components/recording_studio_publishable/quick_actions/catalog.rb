# frozen_string_literal: true

module RecordingStudioPublishable
  module QuickActions
    # Closed states, the verbs on each one, and a menu row.
    module Catalog
      CLOSED_STATES = {
        draft: {
          style: :secondary,
          icon: "pencil-square",
          actions: %i[publish schedule]
        },
        scheduled: {
          style: :default,
          icon: "clock",
          actions: %i[publish schedule unpublish]
        },
        published: {
          style: :default,
          icon: "check-circle",
          icon_variant: :solid,
          icon_style: :success,
          actions: %i[unpublish schedule]
        }
      }.freeze

      ACTIONS = {
        publish: { icon: "rocket-launch", transition: :publish, text_key: "actions.publish_now" },
        schedule: { icon: "clock", text_key: "actions.schedule" },
        unpublish: { icon: "pencil-square", transition: :draft, text_key: "actions.unpublish" }
      }.freeze

      Row = Data.define(:kind, :text, :icon, :href, :target, :rel, :data) do
        def divider? = kind == :divider
        def form? = kind == :form
        def link? = kind == :link
      end
    end
  end
end
