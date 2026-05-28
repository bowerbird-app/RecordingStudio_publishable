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
      return redirect_to_canonical_path(canonical_path) if stale_slug? && canonical_path.present?

      assign_parent_recordable_context(publishable_recording)
      prepare_public_controller_context(public_renderer)
      render_public_template(public_template, public_layout)
    end

    private

    def find_publishable_recording
      uuid = params[:uuid].presence
      return unless uuid

      RecordingStudio::Recording.find_by(
        id: uuid,
        recordable_type: RecordingStudioPublishable::Publishable.name,
        trashed_at: nil
      )
    end

    def public_canonical_path_for(publishable_recording)
      parent_recordable = publishable_recording.parent_recording&.recordable
      return unless parent_recordable.respond_to?(:published_url)

      parent_recordable.published_url
    end

    def stale_slug?
      return false unless params.key?(:slug)

      params[:slug].to_s != @publishable.slug.to_s
    end

    def redirect_to_canonical_path(canonical_path)
      redirect_to canonical_path,
                  status: RecordingStudioPublishable.configuration.canonical_redirect_status,
                  allow_other_host: false
    end

    def assign_parent_recordable_context(publishable_recording)
      @parent_recording = publishable_recording.parent_recording
      @parent_recordable = @parent_recording&.recordable
      @recording = @parent_recording
      @recordable = @parent_recordable
      assign_parent_recordable_instance_variable
    end

    def inferred_parent_recordable_type_for(publishable_recording)
      params[:parent_recordable_type].presence || publishable_recording.parent_recording&.recordable_type
    end

    def public_renderer
      RecordingStudioPublishable.configuration.public_renderer_for(@parent_recording&.recordable_type)
    end

    def public_template
      public_renderer.template_path
    end

    def public_layout
      public_renderer.layout.presence || RecordingStudioPublishable.configuration.layout
    end

    def prepare_public_controller_context(renderer)
      controller_class = resolve_public_controller_class(renderer.controller)
      return unless controller_class

      action_name = renderer.action.presence || :show
      return unless controller_class.action_methods.include?(action_name.to_s)

      public_controller = controller_class.new
      seed_public_controller_assigns(public_controller)
      seed_public_controller_request(public_controller)
      public_controller.public_send(action_name)
      merge_public_controller_assigns(public_controller)
    rescue StandardError
      nil
    end

    def resolve_public_controller_class(controller_name)
      return if controller_name.blank?

      controller_class_name = controller_name.to_s
      unless controller_class_name.end_with?("Controller")
        controller_class_name = "#{controller_class_name.camelize}Controller"
      end
      controller_class = controller_class_name.safe_constantize
      return if controller_class.blank?
      return unless controller_class < ActionController::Base

      controller_class
    rescue NameError
      nil
    end

    def seed_public_controller_assigns(public_controller)
      view_assigns.each do |name, value|
        public_controller.instance_variable_set("@#{name}", value)
      end
    end

    def seed_public_controller_request(public_controller)
      return unless public_controller.respond_to?(:set_request!) && public_controller.respond_to?(:set_response!)

      public_controller.set_request!(request) if request
      public_controller.set_response!(ActionDispatch::Response.new)
    rescue StandardError
      nil
    end

    def merge_public_controller_assigns(public_controller)
      public_controller.view_assigns.each do |name, value|
        instance_variable_set("@#{name}", value)
      end
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
