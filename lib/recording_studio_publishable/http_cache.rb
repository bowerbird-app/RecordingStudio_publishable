# frozen_string_literal: true

require_relative "http_cache/validator"
require_relative "http_cache/commit"

module RecordingStudioPublishable
  # Applies a recordable's HttpCachePolicy on the outer public response.
  # The inner controller renders into a throwaway response, so its headers
  # never reach the client. Freshness runs only after the page is live.
  module HttpCache
    ENV_KEY = "recording_studio_publishable.http_cache"
    PRIVATE_CACHE_CONTROL = "private, no-store"

    module_function

    def apply(controller, preview:)
      if preview || !live?(controller)
        deny!(controller)
        return
      end

      cache_live_page(controller)
    end

    def deny!(controller)
      private_no_store!(controller.response)
      remember!(controller.request, public: false, cache_control: PRIVATE_CACHE_CONTROL)
    end

    def reapply(controller)
      decision = decision_for(controller.request)
      return if decision.blank? || decision[:strip_etag]

      if decision[:public]
        write_public!(controller.response, decision)
        skip_session!(controller.request)
      else
        private_no_store!(controller.response)
      end
    end

    def private_no_store!(response)
      response.set_header("Cache-Control", PRIVATE_CACHE_CONTROL)
    end
  end
end

require_relative "http_cache/live_page"
