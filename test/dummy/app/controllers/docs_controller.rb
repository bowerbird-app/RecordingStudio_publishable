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

  def headers
    @header_recordings = RecordingStudio::Recording.where(recordable_type: %w[Page Article]).includes(:recordable).order(:created_at, :id)
    @header_parent_recording = selected_header_recording
    @header_publishable = @header_parent_recording&.current_publishable
    @header_public_url = @header_parent_recording&.publishable_public_url(
      host: request.host_with_port,
      protocol: request.protocol.delete_suffix("://")
    )
    @header_social_image_url = social_image_preview_url(@header_publishable)
    @header_tag_rows = header_tag_rows
    @header_tag_code = build_header_code
  end

  def components
    require_dependency RecordingStudioPublishable::Engine.root.join("app/components/recording_studio_publishable/status_badge/component").to_s
    require_dependency RecordingStudioPublishable::Engine.root.join("app/components/recording_studio_publishable/quick_actions/component").to_s
    require_dependency RecordingStudioPublishable::Engine.root.join("app/components/recording_studio_publishable/edit_button_component").to_s

    @component_demo_recording = component_demo_recording
    @component_demo_status_badges = component_demo_status_badges
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
        subtitle: "Status-aware edit button preview showing published and draft states.",
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
          {
            name: "show_tooltip:",
            type: "Boolean",
            required: false,
            description: "When true, shows a published/scheduled tooltip on hover (default: false)."
          },
        ],
        preview: :edit_button,
        code: <<~ERB
          <%= render RecordingStudioPublishable::EditButtonComponent.new(recording: @component_demo_recording) %>
          <%= render RecordingStudioPublishable::EditButtonComponent.new(recording: @component_demo_recording, show_tooltip: true) %>
        ERB
      },
      {
        title: "RecordingStudioPublishable::StatusBadge::Component",
        subtitle: "Shows all publishable status badge states for a publishable recordable.",
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
          <%= render RecordingStudioPublishable::StatusBadge::Component.new(publishable: RecordingStudioPublishable::Publishable.new(status: :draft, slug: "draft-demo")) %>
          <%= render RecordingStudioPublishable::StatusBadge::Component.new(publishable: RecordingStudioPublishable::Publishable.new(status: :published, slug: "published-demo")) %>
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

  def selected_header_recording
    selected_id = params[:recording_id].presence
    return @header_recordings.first if selected_id.blank?

    @header_recordings.find { |recording| recording.id == selected_id } || @header_recordings.first
  end

  def social_image_preview_url(publishable)
    return if publishable.blank? || !publishable.social_image_attached?

    path = recording_studio_attachable.attachment_preview_file_path(
      publishable.social_image_attachment_recording,
      variant_name: :square_small
    )

    "#{request.base_url}#{path}"
  rescue StandardError
    nil
  end

  def header_tag_rows
    return [] unless @header_parent_recording && @header_publishable

    page_title = @header_publishable.seo_title.presence || @header_parent_recording.recordable&.try(:title).presence || "Published page"
    description = @header_publishable.seo_description.presence
    canonical_url = @header_publishable.canonical_url.presence || @header_public_url
    social_title = @header_publishable.social_title.presence || page_title
    social_description = @header_publishable.social_description.presence || description
    twitter_card = @header_social_image_url.present? ? "summary_large_image" : "summary"

    rows = []
    rows << ["title", page_title]
    rows << ["meta[name=description]", description] if description.present?
    rows << ["link[rel=canonical]", canonical_url] if canonical_url.present?
    rows << ["meta[property=og:type]", "article"]
    rows << ["meta[property=og:title]", social_title]
    rows << ["meta[property=og:description]", social_description] if social_description.present?
    rows << ["meta[property=og:url]", @header_public_url] if @header_public_url.present?
    rows << ["meta[property=og:image]", @header_social_image_url] if @header_social_image_url.present?
    rows << ["meta[name=twitter:card]", twitter_card]
    rows << ["meta[name=twitter:title]", social_title]
    rows << ["meta[name=twitter:description]", social_description] if social_description.present?
    rows << ["meta[name=twitter:image]", @header_social_image_url] if @header_social_image_url.present?
    rows
  end

  def build_header_code
    lines = []

    @header_tag_rows.each do |name, value|
      case name
      when "title"
        lines << "<title>#{value}</title>"
      when "link[rel=canonical]"
        lines << "<link rel=\"canonical\" href=\"#{value}\">"
      else
        key, key_value = name.match(/meta\[(.+?)=(.+?)\]/).captures
        lines << "<meta #{key}=\"#{key_value}\" content=\"#{value}\">"
      end
    end

    lines.join("\n")
  end

  def component_demo_recording
    RecordingStudio::Recording.where(recordable_type: "Page").includes(:recordable).order(:created_at, :id).first
  end

  def component_demo_edit_button_recordings
    @component_demo_edit_button_recordings ||= begin
      demo_recording = Struct.new(:id, :current_publishable)
      statuses = [
        [:published, RecordingStudioPublishable::Publishable.new(status: :published, slug: "published-demo")],
        [:published_future, RecordingStudioPublishable::Publishable.new(status: :published, slug: "published-future-demo", publish_at: 1.day.from_now)],
        [:draft, RecordingStudioPublishable::Publishable.new(status: :draft, slug: "draft-demo")]
      ]

      statuses.map.with_index(1) do |(name, publishable), index|
        demo_recording.new("demo-#{name}-#{index}", publishable)
      end
    end
  end

  def component_demo_status_badges
    @component_demo_status_badges ||= [
      RecordingStudioPublishable::Publishable.new(status: :draft, slug: "draft-demo"),
      RecordingStudioPublishable::Publishable.new(status: :published, slug: "published-demo")
    ]
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
