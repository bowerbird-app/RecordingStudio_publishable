# frozen_string_literal: true

module RecordingStudioPublishable
  class PublishedController < ApplicationController
    include RendersPublicPage

    skip_before_action :authenticate_user!, raise: false

    def show
      render_public_publishable_page(find_publishable_recording)
    end

    # Root Switchable skips device-cookie resolution when this is true.
    def publishable_public_cache_response?
      policy = RecordingStudioPublishable::HttpCache.fetch_policy(self)
      policy.respond_to?(:public?) && policy.public?
    end

    private

    def find_publishable_recording
      uuid = params[:uuid].presence
      return unless uuid

      RecordingStudio::Recording.kept.find_by(
        id: uuid,
        recordable_type: RecordingStudioPublishable::Publishable.name
      )
    end
  end
end
