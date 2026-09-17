# frozen_string_literal: true

module RecordingStudioPublishable
  class PublishedController < ApplicationController
    include RendersPublicPage

    skip_before_action :authenticate_user!, raise: false

    def show
      render_public_publishable_page(find_publishable_recording)
    end

    private

    def find_publishable_recording
      uuid = params[:uuid].presence
      return unless uuid

      RecordingStudio::Recording.find_by(
        RecordingStudioPublishable::TrashedAt.merge_active(
          id: uuid,
          recordable_type: RecordingStudioPublishable::Publishable.name
        )
      )
    end
  end
end
