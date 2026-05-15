# frozen_string_literal: true

class DocsController < ApplicationController
  def install; end

  def configuration
    render :config
  end

  def recordable_types
    @recordable_types = Array(RecordingStudio.configuration.recordable_types).filter_map do |recordable_type|
      normalize_recordable_type(recordable_type)
    end
  end

  def recordings_tree
    recordings = RecordingStudio::Recording.includes(:recordable).reorder(:created_at, :id).to_a
    recordings_by_parent_id = recordings.group_by(&:parent_recording_id)

    @recording_tree = recordings_by_parent_id.fetch(nil, []).map do |recording|
      build_recording_node(recording, recordings_by_parent_id)
    end
  end

  def gem_views
    prefix = "#{RecordingStudioPublishable::Engine.root}/"

    @engine_views = Dir.glob(RecordingStudioPublishable::Engine.root.join("app/views/recording_studio_publishable/**/*.erb").to_s)
      .sort
      .map { |path| path.delete_prefix(prefix) }
  end

  def methods
    @method_sections = method_sections
  end

  def helpers
    @helper_sections = helper_sections
  end

  def components
    require_dependency RecordingStudioPublishable::Engine.root.join("app/components/recording_studio_publishable/status_badge/component").to_s
    require_dependency RecordingStudioPublishable::Engine.root.join("app/components/recording_studio_publishable/quick_actions/component").to_s
    require_dependency RecordingStudioPublishable::Engine.root.join("app/components/recording_studio_publishable/edit_button/component").to_s

    @component_demo_recording = component_demo_recording
    @component_demo_publishable = @component_demo_recording&.current_publishable
    @component_sections = component_sections
  end

  private

  def method_sections
    [
      {
        title: "RecordingStudioPublishable::ParentRecordable",
        subtitle: "Query helpers for parent recordable models that include the addon concern.",
        code: <<~RUBY
          class Page < ApplicationRecord
            include RecordingStudioPublishable::ParentRecordable

            recording_studio_publishable

            # Class query helpers:
            # - currently_published
            # - scheduled
            # - draft
            # - unpublished
          end
        RUBY
      },
      {
        title: "RecordingStudioPublishable::RecordingExtensions",
        subtitle: "Instance helpers added to RecordingStudio::Recording.",
        code: <<~RUBY
          recording = RecordingStudio::Recording.find(recording_id)

          recording.publishable_child_recording
          recording.current_publishable
          recording.currently_published?
          recording.publishable_public_path
          recording.publishable_public_url(host: "example.test")
        RUBY
      },
      {
        title: "RecordingStudioPublishable::Publishable",
        subtitle: "Scopes and predicates that describe the publishable child state.",
        code: <<~RUBY
          publishable = RecordingStudioPublishable::Publishable.find(publishable_id)

          RecordingStudioPublishable::Publishable.currently_published
          RecordingStudioPublishable::Publishable.currently_live
          RecordingStudioPublishable::Publishable.scheduled
          RecordingStudioPublishable::Publishable.draft
          RecordingStudioPublishable::Publishable.unpublished

          publishable.currently_published?
          publishable.published?
          publishable.scheduled_for_future?
          publishable.previously_published?
          publishable.unpublished?
          publishable.effective_time_zone
        RUBY
      },
      {
        title: "RecordingStudioPublishable::Routing",
        subtitle: "Build the canonical public path and URL for a publishable child recording.",
        code: <<~RUBY
          RecordingStudioPublishable::Routing.path_for(
            publishable_recording: publishable_recording,
            publishable: publishable_recording.recordable,
            parent_recordable_type: publishable_recording.parent_recording&.recordable_type
          )

          RecordingStudioPublishable::Routing.url_for(
            publishable_recording: publishable_recording,
            publishable: publishable_recording.recordable,
            parent_recordable_type: publishable_recording.parent_recording&.recordable_type,
            host: "example.test",
            protocol: "https"
          )
        RUBY
      },
      {
        title: "RecordingStudioPublishable::Configuration",
        subtitle: "Configure routes, renderer overrides, actor lookup, authorization, and the default time zone.",
        code: <<~RUBY
          RecordingStudioPublishable.configuration.register_public_path("Page", path: "/published/:uuid/:slug")
          RecordingStudioPublishable.configuration.register_public_renderer("Page", controller: "pages", action: :show)
          RecordingStudioPublishable.configuration.public_path_for("Page")
          RecordingStudioPublishable.configuration.public_template_for("Page")
          RecordingStudioPublishable.configuration.public_controller_for("Page")
          RecordingStudioPublishable.configuration.public_action_for("Page")
          RecordingStudioPublishable.configuration.authorize_management?(recording: recording, actor: actor)
          RecordingStudioPublishable.configuration.actor_for(controller: controller)
        RUBY
      },
      {
        title: "RecordingStudioPublishable::Services::BaseService",
        subtitle: "Common service object entry point and result wrapper.",
        code: <<~RUBY
          result = RecordingStudioPublishable::Services::ExampleService.call(name: "World")

          result.success?
          result.failure?
          result.on_success { |value| puts value }
          result.on_failure { |error| warn error }
          result.value!
        RUBY
      },
      {
        title: "Publishable services",
        subtitle: "Core service entry points for child creation, updates, transitions, and resolution.",
        code: <<~RUBY
          RecordingStudioPublishable::Services::Publishables::EnsureChild.call(parent_recording: parent_recording, actor: actor)
          RecordingStudioPublishable::Services::Publishables::Update.call(parent_recording: parent_recording, attributes: attributes, actor: actor)
          RecordingStudioPublishable::Services::Publishables::Transition.call(parent_recording: parent_recording, transition: "publish", actor: actor)
          RecordingStudioPublishable::Services::Publishables::Resolve.call(uuid: uuid, slug: slug)
        RUBY
      },
      {
        title: "RecordingStudioPublishable::Services::ExampleService",
        subtitle: "A small example of the service-object pattern shipped with the addon.",
        code: <<~RUBY
          RecordingStudioPublishable::Services::ExampleService.call(name: "World")
        RUBY
      }
    ]
  end

  def helper_sections
    [
      {
        title: "render_publishable_status_badge",
        subtitle: "Legacy helper wrapper for the publishable status badge component.",
        code: <<~RUBY
          <%= render_publishable_status_badge(@publishable) %>
        RUBY
      },
      {
        title: "render_publishable_quick_actions",
        subtitle: "Legacy helper wrapper for the publishable quick actions component.",
        code: <<~RUBY
          <%= render_publishable_quick_actions(@page_recording) %>
        RUBY
      },
    ]
  end

  def component_sections
    [
      {
        title: "RecordingStudioPublishable::EditButton::Component",
        subtitle: "Edit button with status badge, links to the edit route for a publishable.",
        entrypoint: "app/components/recording_studio_publishable/edit_button/component.rb",
        params: [
          {
            name: "publishable:",
            type: "RecordingStudioPublishable::Publishable",
            required: true,
            description: "The publishable recordable to edit."
          },
          {
            name: "label:",
            type: "String",
            required: false,
            description: "Button label text (default: 'Edit')."
          },
          {
            name: "status:",
            type: "String",
            required: false,
            description: "Status to show in the badge (optional)."
          }
        ],
        preview: :edit_button,
        code: <<~ERB
          <%= render RecordingStudioPublishable::EditButton::Component.new(publishable: @component_demo_publishable, status: @component_demo_publishable.status) %>
        ERB
      },
      {
        title: "RecordingStudioPublishable::StatusBadge::Component",
        subtitle: "Shows the current publishable state for a publishable recordable.",
        entrypoint: "app/components/recording_studio_publishable/status_badge/component.rb",
        params: [
          {
            name: "publishable:",
            type: "RecordingStudioPublishable::Publishable",
            required: true,
            description: "The publishable recordable whose current state should be displayed."
          }
        ],
        preview: :status_badge,
        code: <<~ERB
          <%= render RecordingStudioPublishable::StatusBadge::Component.new(publishable: @publishable) %>
        ERB
      },
      {
        title: "RecordingStudioPublishable::QuickActions::Component",
        subtitle: "Renders the primary publishable management actions for a parent recording.",
        entrypoint: "app/components/recording_studio_publishable/quick_actions/component.rb",
        params: [
          {
            name: "recording:",
            type: "RecordingStudio::Recording",
            required: true,
            description: "The parent recording that owns the publishable child and transition routes."
          }
        ],
        preview: :quick_actions,
        code: <<~ERB
          <%= render RecordingStudioPublishable::QuickActions::Component.new(recording: @page_recording) %>
        ERB
      },
    ]
  end

  def component_demo_recording
    RecordingStudio::Recording.where(recordable_type: "Page").includes(:recordable).order(:created_at, :id).first
  end

  def normalize_recordable_type(recordable_type)
    type_name = recordable_type.is_a?(Class) ? recordable_type.name : recordable_type.to_s
    return if type_name.blank?

    {
      name: type_name,
      label: type_name.demodulize.underscore.humanize,
      recordings_count: RecordingStudio::Recording.where(recordable_type: type_name).count,
      recordables_count: count_recordables_for(type_name)
    }
  end

  def count_recordables_for(type_name)
    recordable_class = type_name.safe_constantize
    return 0 unless recordable_class&.<= ActiveRecord::Base
    return 0 unless recordable_class.table_exists?

    recordable_class.count
  rescue ActiveRecord::ActiveRecordError
    0
  end

  def build_recording_node(recording, recordings_by_parent_id)
    {
      label: recording_label(recording),
      children: recordings_by_parent_id.fetch(recording.id, []).map do |child_recording|
        build_recording_node(child_recording, recordings_by_parent_id)
      end
    }
  end

  def recording_label(recording)
    type_label = recording.recordable_type.to_s.demodulize.underscore.humanize
    identifier = recordable_identifier(recording.recordable)

    "#{type_label}: #{identifier}"
  end

  def recordable_identifier(recordable)
    return "Unknown recordable" if recordable.nil?

    %i[name title email label slug identifier].each do |attribute|
      next unless recordable.respond_to?(attribute)

      value = recordable.public_send(attribute)
      return value if value.present?
    end

    actor = recordable.actor if recordable.respond_to?(:actor)
    actor_email = actor.email if actor&.respond_to?(:email) && actor.email.present?

    if recordable.respond_to?(:role) && recordable.role.present? && actor_email.present?
      return "#{recordable.role.to_s.humanize} for #{actor_email}"
    end

    return recordable.role.to_s.humanize if recordable.respond_to?(:role) && recordable.role.present?
    return recordable.minimum_role.to_s.humanize if recordable.respond_to?(:minimum_role) && recordable.minimum_role.present?

    "##{recordable.id}"
  end
end
