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

    def success
      return redirect_to_edit unless flash[:publishable_success]

      assign_publishable_success_state
    end

    def update
      previous_publishable = @parent_recording.publishable_child_recording&.recordable&.dup
      incoming = params.fetch(:publishable, {}).to_unsafe_h.slice(
        "status",
        "publish_at",
        "unpublish_at",
        "time_zone",
        "slug"
      )
      Rails.logger.warn(
        "[PublishableDebug] update request recording_id=#{@parent_recording.id} format=#{request.format.symbol} incoming=#{incoming.inspect}"
      )

      result = RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: @parent_recording,
        attributes: publishable_params,
        actor: current_publishable_actor
      )

      if result.success?
        if request.format.json?
          publishable = @parent_recording.reload.publishable_child_recording&.recordable
          return render json: { error: "Publishable not found" }, status: :unprocessable_entity if publishable.blank?

          Rails.logger.warn(
            "[PublishableDebug] update success(json) recording_id=#{@parent_recording.id} status=#{publishable.status.inspect} publish_at=#{publishable.publish_at.inspect} unpublish_at=#{publishable.unpublish_at.inspect} tz=#{publishable.time_zone.inspect}"
          )

          return render json: {
            status: publishable.published_state? ? "published" : "draft",
            timing_copy: timing_copy_for(publishable),
            scheduled_for_future: publishable.scheduled_for_future?,
            publish_at_input_value: datetime_input_value_for(publishable.publish_at, publishable),
            unpublish_at_input_value: datetime_input_value_for(publishable.unpublish_at, publishable),
            time_zone: publishable.time_zone
          }
        end

        publishable = @parent_recording.reload.publishable_child_recording&.recordable
        Rails.logger.warn(
          "[PublishableDebug] update success(html) recording_id=#{@parent_recording.id} status=#{publishable&.status.inspect} publish_at=#{publishable&.publish_at.inspect} unpublish_at=#{publishable&.unpublish_at.inspect} tz=#{publishable&.time_zone.inspect}"
        )

        return redirect_to_publish_success if publish_success_transition?(previous_publishable, publishable)

        return redirect_to_edit(notice: "Publishable info saved")
      end

      return render json: { error: result.error }, status: :unprocessable_entity if request.format.json?

      Rails.logger.warn("[PublishablesController#update] failure: #{result.error.inspect}")
      redirect_to_edit(alert: result.error.presence || "Publishable info could not be saved")
    end

    def transition
      previous_publishable = @parent_recording.publishable_child_recording&.recordable&.dup
      result = RecordingStudioPublishable::Services::Publishables::Transition.call(
        parent_recording: @parent_recording,
        transition: params[:transition],
        actor: current_publishable_actor
      )

      if request.format.json?
        return render json: { error: result.error }, status: :unprocessable_entity if result.failure?

        publishable = @parent_recording.reload.publishable_child_recording&.recordable
        return render json: { error: "Publishable not found" }, status: :unprocessable_entity if publishable.blank?

        scheduled = publishable.scheduled_for_future?
        Rails.logger.warn("[DEBUG] scheduled_for_future: #{scheduled}")
        Rails.logger.warn("[DEBUG] publish_at: #{publishable.publish_at}")
        Rails.logger.warn("[DEBUG] now: #{Time.current}")

        return render json: {
          status: publishable.published_state? ? "published" : "draft",
          timing_copy: timing_copy_for(publishable),
          scheduled_for_future: scheduled,
          publish_at_input_value: datetime_input_value_for(publishable.publish_at, publishable),
          unpublish_at_input_value: datetime_input_value_for(publishable.unpublish_at, publishable),
          time_zone: publishable.time_zone
        }
      end

      publishable = @parent_recording.reload.publishable_child_recording&.recordable
      return redirect_to_edit(alert: "Publishable not found") if publishable.blank?

      return redirect_to_publish_success if publish_success_transition?(previous_publishable, publishable)

      redirect_to_edit(notice: transition_notice(result), alert: transition_alert(result))
    end

    private

    def load_parent_recording
      requested_recording = RecordingStudio::Recording.find(params[:recording_id])
      @parent_recording = canonical_parent_recording_for(requested_recording)
    end

    def canonical_parent_recording_for(recording)
      return recording unless recording.recordable_type == RecordingStudioPublishable::Publishable.name

      recording.parent_recording || recording
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
      attributes = %i[
        status social_title social_description social_image_attachment_recording_id slug
      ]

      attributes.concat(%i[publish_at unpublish_at time_zone]) if schedule_enabled_for_recordable?

      if seo_enabled_for_recordable?
        attributes.concat(%i[seo_title seo_description meta_robots])
        attributes << :canonical_url
      end

      attributes
    end

    def publishable_layout
      RecordingStudioPublishable.configuration.layout
    end

    def assign_publishable_form_state
      @publishable_recording = @parent_recording.publishable_child_recording
      @publishable = @publishable_recording.recordable
      @schedule_enabled = schedule_enabled_for_recordable?
      @seo_enabled = seo_enabled_for_recordable?
      @time_zone_options = ActiveSupport::TimeZone.all.map do |zone|
        ["(UTC#{zone.formatted_offset}) #{zone.name}", zone.name]
      end
      @social_image_attachments = direct_image_attachments_for(@publishable_recording)
    end

    def assign_publishable_success_state
      @publishable_recording = @parent_recording.publishable_child_recording
      @publishable = @publishable_recording.recordable
      @recordable_name = @parent_recording.recordable.try(:title).presence ||
                         @parent_recording.recordable.try(:name).presence ||
                         @parent_recording.recordable_type.to_s.demodulize.humanize
      @public_path = RecordingStudioPublishable::Routing.url_for(
        publishable_recording: @publishable_recording,
        publishable: @publishable,
        parent_recordable_type: @parent_recording.recordable_type
      )
      @public_url = RecordingStudioPublishable::Routing.url_for(
        publishable_recording: @publishable_recording,
        publishable: @publishable,
        parent_recordable_type: @parent_recording.recordable_type,
        host: request.host_with_port,
        protocol: request.protocol.delete_suffix("://")
      )
    end

    def schedule_enabled_for_recordable?
      RecordingStudioPublishable.configuration.schedule_enabled_for(@parent_recording.recordable_type)
    end

    def seo_enabled_for_recordable?
      RecordingStudioPublishable.configuration.seo_enabled_for(@parent_recording.recordable_type)
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
      redirect_to(
        edit_recording_publishable_path(recording_id: @parent_recording.id),
        notice: notice,
        alert: alert,
        status: :see_other
      )
    end

    def redirect_to_publish_success
      flash[:publishable_success] = true
      redirect_to publishable_success_path(recording_id: @parent_recording.id), status: :see_other
    end

    def transition_notice(result)
      result.success? ? "Publishable status updated" : nil
    end

    def transition_alert(result)
      result.failure? ? result.error : nil
    end

    def timing_copy_for(publishable)
      return nil unless publishable.published_state?

      publish_at_time = publishable.publish_at&.in_time_zone(publishable.effective_time_zone)
      return "Published just now" if publish_at_time.blank?

      if publish_at_time > Time.current
        "Scheduled to publish in #{helpers.distance_of_time_in_words(Time.current, publish_at_time)}"
      else
        "Published #{helpers.time_ago_in_words(publish_at_time)} ago"
      end
    end

    def datetime_input_value_for(value, publishable)
      return nil if value.blank?

      value.in_time_zone(publishable.effective_time_zone).strftime("%Y-%m-%dT%H:%M")
    end

    def publish_success_transition?(previous_publishable, current_publishable)
      return false if previous_publishable.blank? || current_publishable.blank?
      return false if previous_publishable.published_state?
      return false unless current_publishable.published_state?
      return false if current_publishable.scheduled_for_future?

      true
    end
  end
end
