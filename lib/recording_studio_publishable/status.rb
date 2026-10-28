# frozen_string_literal: true

module RecordingStudioPublishable
  module Status
    module_function

    def label(publishable)
      return Copy.t("status.scheduled") if publishable&.scheduled_for_future?
      return Copy.t("status.published") if publishable&.published_state?

      Copy.t("status.draft")
    end

    def badge_style(publishable)
      return :warning if publishable&.scheduled_for_future?
      return :success if publishable&.published_state?

      :info
    end
  end
end
