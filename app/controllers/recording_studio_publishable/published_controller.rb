# frozen_string_literal: true

module RecordingStudioPublishable
  class PublishedController < ApplicationController
    skip_before_action :authenticate_user!, raise: false

    def show
      publishable_recording = find_publishable_recording
      return head :not_found unless publishable_recording

      @publishable_recording = publishable_recording
      @publishable = publishable_recording.recordable
      return head :not_found unless @publishable.currently_published?

      canonical_path = public_canonical_path_for(publishable_recording)
      return redirect_to_canonical_path(canonical_path) if stale_slug?

      assign_parent_recordable_context(publishable_recording)
      render_public_template(public_template, public_layout)
    end

    private

    def find_publishable_recording
      RecordingStudio::Recording.find_by(
        id: params[:uuid],
        recordable_type: RecordingStudioPublishable::Publishable.name,
        trashed_at: nil
      )
    end

    def public_canonical_path_for(publishable_recording)
      RecordingStudioPublishable::Routing.path_for(
        publishable_recording: publishable_recording,
        publishable: @publishable,
        parent_recordable_type: publishable_recording.parent_recording&.recordable_type
      )
    end

    def stale_slug?
      params[:slug].to_s != @publishable.slug.to_s
    end

    def redirect_to_canonical_path(canonical_path)
      redirect_to canonical_path, status: RecordingStudioPublishable.configuration.canonical_redirect_status
    end

    def assign_parent_recordable_context(publishable_recording)
      @parent_recording = publishable_recording.parent_recording
      @parent_recordable = @parent_recording&.recordable
      @recording = @parent_recording
      @recordable = @parent_recordable
      assign_parent_recordable_instance_variable
    end

    def public_template
      RecordingStudioPublishable.configuration.public_template_for(@parent_recording&.recordable_type)
    end

    def public_layout
      renderer = RecordingStudioPublishable.configuration.public_renderer_for(@parent_recording&.recordable_type)
      renderer.layout.presence || RecordingStudioPublishable.configuration.default_layout
    end

    def render_public_template(template, layout)
      prepend_view_path(Rails.root.join("app/views")) if defined?(Rails)
      render template: template, layout: layout
    rescue ActionView::MissingTemplate
      render template: "recording_studio_publishable/published/show", layout: layout
    end

    def assign_parent_recordable_instance_variable
      return unless @parent_recordable && @parent_recording&.recordable_type.present?

      variable_name = @parent_recording.recordable_type.to_s.demodulize.underscore
      instance_variable_set("@#{variable_name}", @parent_recordable)
    end
  end
end
