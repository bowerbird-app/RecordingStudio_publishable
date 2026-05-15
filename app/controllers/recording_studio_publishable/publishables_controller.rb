# frozen_string_literal: true

module RecordingStudioPublishable
  class PublishablesController < ApplicationController
    layout :publishable_layout

    before_action :load_parent_recording
    before_action -> { authorize_publishable_management!(@parent_recording) }
    before_action :ensure_publishable_child

    def edit
      assign_publishable_form_state
    end

    def update
      result = RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: @parent_recording,
        attributes: publishable_params,
        actor: current_publishable_actor
      )

      return redirect_to_edit(notice: "Publishable info saved") if result.success?

      assign_publishable_form_state
      flash.now[:alert] = result.error
      render :edit, status: :unprocessable_entity
    end

    def transition
      result = RecordingStudioPublishable::Services::Publishables::Transition.call(
        parent_recording: @parent_recording,
        transition: params[:transition],
        actor: current_publishable_actor
      )

      redirect_to_edit(notice: transition_notice(result), alert: transition_alert(result))
    end

    private

    def load_parent_recording
      @parent_recording = RecordingStudio::Recording.find(params[:recording_id])
    end

    def ensure_publishable_child
      result = RecordingStudioPublishable::Services::Publishables::EnsureChild.call(
        parent_recording: @parent_recording,
        actor: current_publishable_actor
      )
      return unless result.failure?

      flash.now[:alert] = result.error
      render plain: result.error, status: :unprocessable_entity
    end

    def publishable_params
      params.require(:publishable).permit(*permitted_publishable_attributes)
    end

    def permitted_publishable_attributes
      %i[
        slug status publish_at unpublish_at time_zone seo_title seo_description canonical_url meta_robots
        social_title social_description social_image_attachment_recording_id
      ]
    end

    def publishable_layout
      config = RecordingStudioPublishable.configuration
      return config.layout unless config.respond_to?(:edit_layout)

      config.edit_layout.presence || config.layout
    end

    def assign_publishable_form_state
      @publishable_recording = @parent_recording.publishable_child_recording
      @publishable = @publishable_recording.recordable
      @time_zones = ActiveSupport::TimeZone.all.map(&:name)
      @social_image_attachments = direct_image_attachments_for(@publishable_recording)
    end

    def direct_image_attachments_for(publishable_recording)
      publishable_recording.recordings_query(
        include_children: true,
        type: "RecordingStudioAttachable::Attachment",
        parent_id: publishable_recording.id,
        recordable_filters: { attachment_kind: "image" }
      ).includes(recordable: [{ file_attachment: :blob }])
    rescue StandardError
      []
    end

    def redirect_to_edit(notice: nil, alert: nil)
      redirect_to edit_recording_publishable_path(recording_id: @parent_recording.id), notice: notice, alert: alert
    end

    def transition_notice(result)
      result.success? ? "Publishable status updated" : nil
    end

    def transition_alert(result)
      result.failure? ? result.error : nil
    end
  end
end
