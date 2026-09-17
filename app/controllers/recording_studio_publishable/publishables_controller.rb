# frozen_string_literal: true

require "recording_studio_publishable/publish_jobs"

module RecordingStudioPublishable
  class PublishablesController < ApplicationController
    layout :publishable_layout

    before_action :load_parent_recording
    before_action -> { authorize_publishable_management!(@parent_recording) }
    before_action :ensure_publishable_child

    def edit
      assign_publishable_hub_state
    end

    def schedule
      return redirect_to_edit unless schedule_enabled_for_recordable?

      assign_publishable_form_state
    end

    def search
      assign_publishable_form_state
    end

    def social
      assign_publishable_form_state
    end

    def success
      return redirect_to_edit unless flash[:publishable_success]

      assign_publishable_success_state
    end

    def update
      job = current_publish_job

      if job.blank?
        return update_without_section if request.format.json?

        return redirect_to_edit
      end

      return redirect_to_edit if job.key == :schedule && !schedule_enabled_for_recordable?

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
        return render_json_update if request.format.json?

        publishable = @parent_recording.reload.publishable_child_recording&.recordable
        Rails.logger.warn(
          "[PublishableDebug] update success(html) recording_id=#{@parent_recording.id} status=#{publishable&.status.inspect} publish_at=#{publishable&.publish_at.inspect} unpublish_at=#{publishable&.unpublish_at.inspect} tz=#{publishable&.time_zone.inspect}"
        )

        return redirect_to_job(job, notice: job.notice)
      end

      return render json: { error: result.error }, status: :unprocessable_entity if request.format.json?

      Rails.logger.warn("[PublishablesController#update] failure: #{result.error.inspect}")
      redirect_to_job(job, alert: result.error.presence || "Could not save that.")
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
      return respond_inline_transition(result, publishable) if inline_transition?

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

    def current_publish_job
      RecordingStudioPublishable::PublishJobs.fetch(params[:section])
    end

    def publishable_params
      permitted = params.require(:publishable).permit(*permitted_publishable_attributes)
      return permitted unless current_publish_job&.key == :schedule
      return permitted if permitted[:publish_at].blank?

      permitted.merge(status: "published")
    end

    def permitted_publishable_attributes
      job = current_publish_job
      return capability_publishable_attributes if job.blank?

      job.attributes & capability_publishable_attributes
    end

    def capability_publishable_attributes
      attributes = %i[
        status social_title social_description social_image_attachment_recording_id slug
      ]

      attributes.concat(%i[publish_at unpublish_at time_zone]) if schedule_enabled_for_recordable?

      attributes.concat(%i[canonical_url meta_robots])
      attributes.concat(%i[seo_title seo_description]) if seo_enabled_for_recordable?

      attributes
    end

    def publishable_layout
      RecordingStudioPublishable.configuration.layout
    end

    def assign_publishable_hub_state
      @management_close_url = management_close_url
      @recordable_name = parent_page_name
      @publish_jobs = RecordingStudioPublishable::PublishJobs.listed(schedule_enabled: schedule_enabled_for_recordable?)
    end

    def assign_publishable_form_state
      @job = RecordingStudioPublishable::PublishJobs.fetch(action_name)
      @publishable_recording = @parent_recording.publishable_child_recording
      @publishable = @publishable_recording.recordable
      @management_close_url = management_close_url
      @schedule_enabled = schedule_enabled_for_recordable?
      @seo_enabled = seo_enabled_for_recordable?
      @recordable_name = parent_page_name
      @time_zone_options = ActiveSupport::TimeZone.all.map do |zone|
        ["(UTC#{zone.formatted_offset}) #{zone.name}", zone.name]
      end
      @social_image_attachments = direct_image_attachments_for(@publishable_recording)
    end

    def assign_publishable_success_state
      @publishable_recording = @parent_recording.publishable_child_recording
      @publishable = @publishable_recording.recordable
      @management_close_url = management_close_url
      @recordable_name = parent_page_name
      @public_path = @parent_recording.recordable.respond_to?(:published_url) ? @parent_recording.recordable.published_url : nil
      @public_url = @public_path.present? ? "#{request.protocol}#{request.host_with_port}#{@public_path}" : nil
    end

    def parent_page_name
      recordable = @parent_recording.recordable
      recordable.try(:title).presence || recordable.try(:name).presence ||
        @parent_recording.recordable_type.to_s.demodulize.humanize
    end

    def schedule_enabled_for_recordable?
      RecordingStudioPublishable.configuration.schedule_enabled_for(@parent_recording.recordable_type)
    end

    def seo_enabled_for_recordable?
      RecordingStudioPublishable.configuration.seo_enabled_for(@parent_recording.recordable_type)
    end

    def management_close_url
      RecordingStudioPublishable.configuration.management_close_url_for(
        controller: self,
        recording: @parent_recording
      )
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

    def inline_transition?
      params[:inline].present? || turbo_stream_request?
    end

    def turbo_stream_request?
      return true if request.format.symbol == :turbo_stream

      request.get_header("HTTP_ACCEPT").to_s.include?("text/vnd.turbo-stream.html")
    end

    def respond_inline_transition(result, publishable)
      if result.failure? || publishable.blank?
        message = result.error.presence || "Could not update this page."
        return render_inline_transition(alert: message, status: :unprocessable_entity)
      end

      live = publishable.published_state? && !publishable.scheduled_for_future?
      notice = live ? "It's live." : "Back to a draft."

      render_inline_transition(notice: notice)
    end

    def render_inline_transition(notice: nil, alert: nil, status: :ok)
      if turbo_stream_request?
        @transition_notice = notice
        @transition_alert = alert
        return render :transition, formats: [:turbo_stream], status: status
      end

      redirect_back(
        fallback_location: inline_fallback_location,
        notice: notice,
        alert: alert,
        status: :see_other,
        allow_other_host: false
      )
    end

    def inline_fallback_location
      return main_app.root_path if defined?(main_app) && main_app.respond_to?(:root_path)

      edit_recording_publishable_path(recording_id: @parent_recording.id)
    end

    def redirect_to_edit(notice: nil, alert: nil)
      redirect_to(
        edit_recording_publishable_path(recording_id: @parent_recording.id),
        notice: notice,
        alert: alert,
        status: :see_other
      )
    end

    def redirect_to_job(job, notice: nil, alert: nil)
      redirect_to(
        public_send(RecordingStudioPublishable::PublishJobs.path_method(job), recording_id: @parent_recording.id),
        notice: notice,
        alert: alert,
        status: :see_other
      )
    end

    def redirect_to_publish_success
      flash[:publishable_success] = true
      redirect_to publishable_success_path(recording_id: @parent_recording.id), status: :see_other
    end

    def update_without_section
      result = RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: @parent_recording,
        attributes: params.require(:publishable).permit(*capability_publishable_attributes),
        actor: current_publishable_actor
      )

      return render json: { error: result.error }, status: :unprocessable_entity if result.failure?

      render_json_update
    end

    def render_json_update
      publishable = @parent_recording.reload.publishable_child_recording&.recordable
      return render json: { error: "Publishable not found" }, status: :unprocessable_entity if publishable.blank?

      Rails.logger.warn(
        "[PublishableDebug] update success(json) recording_id=#{@parent_recording.id} status=#{publishable.status.inspect} publish_at=#{publishable.publish_at.inspect} unpublish_at=#{publishable.unpublish_at.inspect} tz=#{publishable.time_zone.inspect}"
      )

      render json: {
        status: publishable.published_state? ? "published" : "draft",
        timing_copy: timing_copy_for(publishable),
        scheduled_for_future: publishable.scheduled_for_future?,
        publish_at_input_value: datetime_input_value_for(publishable.publish_at, publishable),
        unpublish_at_input_value: datetime_input_value_for(publishable.unpublish_at, publishable),
        time_zone: publishable.time_zone
      }
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

    helper_method :publish_job_path

    def publish_job_path(job)
      public_send(RecordingStudioPublishable::PublishJobs.path_method(job), recording_id: @parent_recording.id)
    end
  end
end
