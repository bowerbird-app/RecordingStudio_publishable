# frozen_string_literal: true

module RecordingStudioPublishable
  class PublicationsController < ApplicationController
    skip_forgery_protection
    skip_before_action :authenticate_user!, raise: false

    def show
      publishable_recording = RecordingStudio::Recording.find_by(
        id: params[:uuid],
        recordable_type: RecordingStudioPublishable::Publishable.name,
        trashed_at: nil
      )
      return head :not_found unless publishable_recording

      @publishable_recording = publishable_recording
      @publishable = publishable_recording.recordable
      return head :not_found unless @publishable.currently_published?

      canonical_path = RecordingStudioPublishable::Routing.path_for(
        publishable_recording: publishable_recording,
        publishable: @publishable,
        parent_recordable_type: publishable_recording.parent_recording&.recordable_type
      )
      if params[:slug].to_s != @publishable.slug.to_s
        return redirect_to canonical_path, status: RecordingStudioPublishable.configuration.canonical_redirect_status
      end

      @parent_recording = publishable_recording.parent_recording
      @parent_recordable = @parent_recording&.recordable
    end
  end
end
