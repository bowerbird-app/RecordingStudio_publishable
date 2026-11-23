# frozen_string_literal: true

module RecordingStudioPublishable
  module Api
    module PublishableSnapshot
      FIELDS = {
        status: entry(
          description: "The publish state to set on this recording: draft, published, or scheduled. Optional. " \
                       "Leave it out to keep the current state from the nested snapshot. scheduled is stored as " \
                       "published and does not itself set publish_at; pass a future publish_at to schedule it. " \
                       "draft clears publish_at and unpublish_at, like unpublish. published makes it live, or " \
                       "keeps it live; if you leave publish_at out, the current time is kept, or set to now if " \
                       "there is none.",
          contract: { type: :string, required: false, allow_blank: false, enum: STATUS_VALUES },
          schema: { type: "string", enum: STATUS_VALUES }
        ),
        slug: entry(
          description: "The public URL slug for this recording. Optional. Leave it out to keep the current slug " \
                       "from the nested snapshot. The saved slug is cleaned into lowercase URL-safe segments " \
                       "(letters, numbers, and hyphens). For example, My Slug is saved as my-slug. A slug is not " \
                       "rejected.",
          contract: TEXT_CONTRACT,
          schema: { type: "string" }
        ),
        publish_at: entry(
          description: "When this recording should go live, as a date and time. Optional. Parsed in time_zone " \
                       "(or the current zone on the nested snapshot, or this gem's default). An invalid date or " \
                       "time is rejected. An empty string, when status is published, publishes immediately (the " \
                       "time is set to now). Leave it out when status is published to keep the current time, or " \
                       "to set now if there is none. A past time is accepted and means it is already live, if " \
                       "status is published and unpublish_at is still in the future or empty. When status is " \
                       "draft, this value is cleared.",
          contract: TIME_CONTRACT,
          schema: TIME_SCHEMA,
          time: true
        ),
        unpublish_at: entry(
          description: "When this recording should go back to draft, as a date and time. Optional. Same parsing " \
                       "as publish_at. Leave it out to keep the current value on the nested snapshot, unless you " \
                       "also set status to published, in which case omitting it clears a scheduled unpublish. " \
                       "When both times are set and status is published, unpublish_at must be later than " \
                       "publish_at. When status is draft, this value is cleared.",
          contract: TIME_CONTRACT,
          schema: TIME_SCHEMA,
          time: true
        ),
        time_zone: entry(
          description: "Time zone for publish_at and unpublish_at, like UTC or Asia/Manila. Optional. Leave it " \
                       "out to keep the current zone on the nested snapshot, or this gem's default when there is " \
                       "none.",
          contract: TEXT_CONTRACT,
          schema: TEXT_SCHEMA
        ),
        seo_title: entry(
          description: "The title used in search results for this recording. Optional. Leave it out to keep the " \
                       "current value on the nested snapshot. Send an empty string to clear it.",
          contract: TEXT_CONTRACT,
          schema: TEXT_SCHEMA
        ),
        seo_description: entry(
          description: "The line under the title in search results for this recording, at most 160 characters. " \
                       "Optional. Leave it out to keep the current value on the nested snapshot. Send an empty " \
                       "string to clear it.",
          contract: TEXT_CONTRACT,
          schema: TEXT_SCHEMA
        ),
        canonical_url: entry(
          description: "The preferred public URL for this recording. Optional. Leave it out to keep the current " \
                       "value on the nested snapshot. Send an empty string to clear it.",
          contract: TEXT_CONTRACT,
          schema: TEXT_SCHEMA
        ),
        meta_robots: entry(
          description: "Search-engine robots value for this recording, for example index,follow. Optional. " \
                       "Leave it out to keep the current value on the nested snapshot. Send an empty string to " \
                       "clear it.",
          contract: TEXT_CONTRACT,
          schema: TEXT_SCHEMA
        ),
        social_title: entry(
          description: "The title used when this recording is shared. Optional. Leave it out to keep the " \
                       "current value on the nested snapshot. Send an empty string to clear it.",
          contract: TEXT_CONTRACT,
          schema: TEXT_SCHEMA
        ),
        social_description: entry(
          description: "The description used when this recording is shared, at most 200 characters. Optional. " \
                       "Leave it out to keep the current value on the nested snapshot. Send an empty string to " \
                       "clear it.",
          contract: TEXT_CONTRACT,
          schema: TEXT_SCHEMA
        ),
        social_image_attachment_recording_id: entry(
          description: "The id of an existing image attachment that is a direct child of this recording's nested " \
                       "publishable snapshot. Use the id returned when that image was attached there, not an " \
                       "image on this recording itself. Optional. Leave it out to keep the current image. Send " \
                       "an empty string to clear it. A missing id, a non-image attachment, or an image that is " \
                       "not a direct child of that nested snapshot, is rejected.",
          contract: TEXT_CONTRACT,
          schema: TEXT_SCHEMA,
          identifier: true
        )
      }.freeze
    end
  end
end
