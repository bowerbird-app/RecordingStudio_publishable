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

      if result.success?
        if request.format.json?
          publishable = @parent_recording.reload.publishable_child_recording&.recordable
          return render json: { error: "Publishable not found" }, status: :unprocessable_entity if publishable.blank?

          return render json: {
            status: publishable.published_state? ? "published" : "draft",
            timing_copy: timing_copy_for(publishable),
            publish_at_input_value: datetime_input_value_for(publishable.publish_at, publishable),
            unpublish_at_input_value: datetime_input_value_for(publishable.unpublish_at, publishable),
            time_zone: publishable.time_zone
          }
        end

        return redirect_to_edit(notice: "Publishable info saved")
      end

      return render json: { error: result.error }, status: :unprocessable_entity if request.format.json?

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
        slug status published_toggle publish_at unpublish_at time_zone seo_title seo_description canonical_url meta_robots
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
      @time_zone_options = ActiveSupport::TimeZone.all.map do |zone|
        ["(UTC#{zone.formatted_offset}) #{zone.name}", zone.name]
      end
      @social_image_attachments = direct_image_attachments_for(@publishable_recording)
      @publishable_history_events = publishable_history_events_for(@publishable_recording)
    end

    def publishable_history_events_for(publishable_recording)
      return [] unless publishable_recording.respond_to?(:events)

      events = publishable_recording.events.order(occurred_at: :desc).to_a
      return [] if events.empty?

      publishable_ids = events.flat_map { |event| [event.recordable_id, event.previous_recordable_id] }.compact.uniq
      snapshots = RecordingStudioPublishable::Publishable.where(id: publishable_ids).index_by(&:id)

      events.filter_map do |event|
        current = snapshots[event.recordable_id]
        previous = snapshots[event.previous_recordable_id]
        label = history_label_for(event, current: current, previous: previous)
        next if label.blank?

        occurred_at = event.occurred_at || event.created_at
        next if occurred_at.blank?

        { label: label, occurred_at: occurred_at }
      end
    rescue StandardError
      []
    end

    def history_label_for(event, current:, previous:)
      action = event.action.to_s.downcase
      return "Unpublished" if action.include?("unpublish")
      return "Scheduled" if action.include?("schedule")
      return "Published" if action.include?("publish")

      return nil if current.blank?

      status_changed = previous.nil? || current.status != previous.status
      publish_at_changed = previous.nil? || current.publish_at != previous.publish_at
      unpublish_at_changed = previous.nil? || current.unpublish_at != previous.unpublish_at

      event_time = event.occurred_at || event.created_at || Time.current

      if current.published_state?
        if current.publish_at.present? && current.publish_at > event_time && (status_changed || publish_at_changed)
          return "Scheduled"
        end

        return "Published" if status_changed || publish_at_changed
      elsif previous&.published_state? || unpublish_at_changed
        return "Unpublished"
      end

      nil
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
  end
end
