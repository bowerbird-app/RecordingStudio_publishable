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

  def components
    require_dependency RecordingStudioPublishable::Engine.root.join("app/components/recording_studio_publishable/status_badge/component").to_s
    require_dependency RecordingStudioPublishable::Engine.root.join("app/components/recording_studio_publishable/quick_actions/component").to_s
    require_dependency RecordingStudioPublishable::Engine.root.join("app/components/recording_studio_publishable/edit_button_component").to_s

    @component_demo_recording = component_demo_recording
    @component_demo_publishable = @component_demo_recording&.current_publishable
    @component_demo_edit_button_recordings = component_demo_edit_button_recordings
    @component_sections = component_sections
  end

  private

  def method_sections
    [
      {
        title: "RecordingStudioPublishable::ParentRecordable",
        subtitle: "Query helpers that return the parent recordables, not the publishable child records.",
        code: <<~RUBY
          class Page < ApplicationRecord
            include RecordingStudioPublishable::ParentRecordable

            recording_studio_publishable
          end

          # Returns Page records whose publishable child is live right now.
          Page.currently_published

          # Returns Page records whose publishable child is scheduled for the future.
          Page.scheduled

          # Returns Page records whose publishable child is still a draft.
          Page.draft

          # Returns Page records whose publishable child has been explicitly unpublished.
          Page.unpublished

          # Same query helpers return Article records for any model that includes
          # RecordingStudioPublishable::ParentRecordable.
          Article.currently_published
        RUBY
      },
      {
        title: "RecordingStudioPublishable::RecordingExtensions",
        subtitle: "Instance helpers added to RecordingStudio::Recording.",
        code: <<~RUBY
          recording = RecordingStudio::Recording.find(recording_id)

          # Returns the publishable child recording (RecordingStudio::Recording).
          recording.publishable_child_recording

          # Returns the current publishable recordable (e.g., Publishable).
          recording.current_publishable

          # Returns true if the recording is currently published.
          recording.currently_published?

          # Returns the public path for the publishable recording.
          recording.publishable_public_path

          # Returns the public URL for the publishable recording, given a host.
          recording.publishable_public_url(host: "example.test")
        RUBY
      },
      {
        title: "RecordingStudioPublishable::Publishable",
        subtitle: "Scopes and predicates for the publishable child records themselves.",
        code: <<~RUBY
          publishable = RecordingStudioPublishable::Publishable.find(publishable_id)

          # Returns publishable records that are live right now.
          RecordingStudioPublishable::Publishable.currently_published

          # Returns publishable records scheduled for a future publish_at time.
          RecordingStudioPublishable::Publishable.scheduled

          # Returns publishable records with draft status.
          RecordingStudioPublishable::Publishable.draft

          # Returns publishable records with unpublished status.
          RecordingStudioPublishable::Publishable.unpublished

          # Returns true when this publishable is currently live.
          publishable.currently_published?

          # Returns the same boolean as currently_published?.
          publishable.published?

          # Returns true when status is scheduled and publish_at is in the future.
          publishable.scheduled_for_future?

          # Returns true when this record was published before and is no longer live.
          publishable.previously_published?

          # Returns true when this record is no longer live and counts as unpublished.
          publishable.unpublished?

          # Returns the configured time zone for this publishable, or the addon default.
          publishable.effective_time_zone
        RUBY
      },
      {
        title: "RecordingStudioPublishable::Routing",
        subtitle: "Build the canonical public path and URL for a publishable child recording.",
        code: <<~RUBY
          # Returns a path like /published/:uuid/:slug with placeholders filled in.
          RecordingStudioPublishable::Routing.path_for(
            publishable_recording: publishable_recording,
            publishable: publishable_recording.recordable,
            parent_recordable_type: publishable_recording.parent_recording&.recordable_type
          )

          # Returns a full URL string when host is present, otherwise just the path.
          RecordingStudioPublishable::Routing.url_for(
            publishable_recording: publishable_recording,
            publishable: publishable_recording.recordable,
            parent_recordable_type: publishable_recording.parent_recording&.recordable_type,
            host: "example.test",
            protocol: "https"
          )
        RUBY
      }
    ]
  end

  def component_sections
    [
      {
        title: "RecordingStudioPublishable::EditButtonComponent",
        subtitle: "Status-aware edit button preview showing published, scheduled, draft, and unpublished states.",
        entrypoint: "app/components/recording_studio_publishable/edit_button_component.rb",
        params: [
          {
            name: "recording:",
            type: "RecordingStudio::Recording",
            required: true,
            description: "The parent recording whose publishable child should be edited."
          },
          {
            name: "label:",
            type: "String",
            required: false,
            description: "Button label text (default: 'Edit')."
          },
        ],
        preview: :edit_button,
        code: <<~ERB
          <%= render RecordingStudioPublishable::EditButtonComponent.new(recording: @component_demo_recording) %>
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

  def component_demo_edit_button_recordings
    @component_demo_edit_button_recordings ||= begin
      demo_recording = Struct.new(:id, :current_publishable)
      statuses = [
        [:published, RecordingStudioPublishable::Publishable.new(status: :published, slug: "published-demo")],
        [:scheduled, RecordingStudioPublishable::Publishable.new(status: :scheduled, slug: "scheduled-demo", publish_at: 1.day.from_now)],
        [:draft, RecordingStudioPublishable::Publishable.new(status: :draft, slug: "draft-demo")],
        [:unpublished, RecordingStudioPublishable::Publishable.new(status: :unpublished, slug: "unpublished-demo")]
      ]

      statuses.map.with_index(1) do |(name, publishable), index|
        demo_recording.new("demo-#{name}-#{index}", publishable)
      end
    end
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
