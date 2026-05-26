# frozen_string_literal: true

class DocsController < ApplicationController
  def install; end

  def configuration
    render :config
  end

  def recordable_types
    @recordable_types = RecordingStudio::RecordableTypesService.filtered_types
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
    @header_publishable_recording = @header_parent_recording&.publishable_child_recording
    @header_publishable = @header_parent_recording&.current_publishable
    @header_public_url = @header_parent_recording&.publishable_public_url(
      host: request.host_with_port,
      protocol: request.protocol.delete_suffix("://")
    )
    @header_social_image_url = social_image_preview_url(@header_publishable)
    @header_publishability_rows = header_publishability_rows
    @header_tag_code = build_header_code_from_helper
    @header_tag_rows = header_tag_rows
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
        title: "RecordingStudioPublishable::Configuration",
        subtitle: "Set global defaults in the initializer and prefer model-level publishable declarations for per-type routing.",
        code: <<~RUBY
          RecordingStudioPublishable.configure do |config|
            config.default_time_zone = "America/Los_Angeles"
            config.layout = "recording_studio_publishable/application"
            config.canonical_redirect_status = :found
          end

          class Page < ApplicationRecord
            include RecordingStudioPublishable::ParentRecordable

            recording_studio_publishable(
              public_controller: "pages",
              public_action: :show,
              schedule: false,
              seo: false
            )
          end

          class Article < ApplicationRecord
            include RecordingStudioPublishable::ParentRecordable

            recording_studio_publishable(
              public_controller: "articles",
              public_action: :show,
              path: "/blogs/:uuid/:slug",
              schedule: true,
              seo: true
            )
          end
        RUBY
      },
      {
        title: "RecordingStudioPublishable::ParentRecordable",
        subtitle: "Scopes you call on parent models (like Page/Article) that filter by publishable state and still return parent model records, not child Publishable rows.",
        code: <<~RUBY
          class Page < ApplicationRecord
            include RecordingStudioPublishable::ParentRecordable

            recording_studio_publishable(
              public_controller: "pages",
              public_action: :show,
              schedule: false,
              seo: false
            )
          end

          # Per-model capability flags are readable from configuration.
          RecordingStudioPublishable.configuration.schedule_enabled_for("Page")
          RecordingStudioPublishable.configuration.seo_enabled_for("Page")

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
        subtitle: "Methods you call directly on RecordingStudio::Recording to filter recordings by publishable state and access publishable-related helpers on each recording.",
        code: <<~RUBY
          # Returns recordings whose publishable child is live right now.
          RecordingStudio::Recording.currently_published

          # Returns recordings whose publishable child is scheduled for the future.
          RecordingStudio::Recording.scheduled_publishables

          # Returns recordings whose publishable child is still a draft.
          RecordingStudio::Recording.draft_publishables

          # Returns recordings whose publishable child was previously live and is now unpublished.
          RecordingStudio::Recording.unpublished_publishables

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
        subtitle: "Methods on the Publishable child model itself, including scopes for publish state and boolean checks for one publishable record.",
        code: <<~RUBY
          publishable = RecordingStudioPublishable::Publishable.find(publishable_id)

          # Returns publishable records that are live right now.
          RecordingStudioPublishable::Publishable.currently_published

          # Returns publishable records scheduled for a future publish_at time.
          RecordingStudioPublishable::Publishable.scheduled

          # Returns publishable records with draft status.
          RecordingStudioPublishable::Publishable.draft

          # Returns publishable records that were previously live and are now unpublished.
          RecordingStudioPublishable::Publishable.unpublished

          # Returns true when the normalized status is published.
          publishable.published_state?

          # Returns true when the normalized status is draft.
          publishable.draft_state?

          # Returns true when this publishable is currently live.
          publishable.currently_published?

          # Returns the same boolean as currently_published?.
          publishable.published?

          # Returns true when status is published and publish_at is in the future.
          publishable.scheduled_for_future?

          # Returns true when this record was published before and is no longer live.
          publishable.previously_published?

          # Returns true when this record is no longer live and counts as unpublished.
          publishable.unpublished?

          # Returns the configured time zone for this publishable, or the addon default.
          publishable.effective_time_zone

          # Returns true when the social image attachment integration is available.
          publishable.social_image_supported?

          # Returns the attached social image recordable, when present.
          publishable.social_image_attachment

          # Returns true when a social image attachment has been linked.
          publishable.social_image_attached?
        RUBY
      },
      {
        title: "RecordingStudioPublishable::Routing",
        subtitle: "Build the canonical public path and URL for a publishable child recording.",
        code: <<~RUBY
          # Returns a path like /published/:uuid/:slug or a configured alternative such as /blogs/:uuid/:slug.
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
        subtitle: "Status-aware edit button preview showing draft, scheduled, and published states.",
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
          <% @component_demo_edit_button_recordings.each do |recording| %>
            <%= render RecordingStudioPublishable::EditButtonComponent.new(recording: recording) %>
          <% end %>

          <% @component_demo_edit_button_recordings.each do |recording| %>
            <%= render RecordingStudioPublishable::EditButtonComponent.new(recording: recording, show_tooltip: true) %>
          <% end %>
        ERB
      },
      {
        title: "RecordingStudioPublishable::StatusBadge::Component",
        subtitle: "Shows draft, scheduled, and published badge states for a publishable recordable.",
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
          <%= render RecordingStudioPublishable::StatusBadge::Component.new(publishable: RecordingStudioPublishable::Publishable.new(status: :published, slug: "scheduled-demo", publish_at: 1.day.from_now)) %>
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
          <%= render RecordingStudioPublishable::QuickActions::Component.new(recording: @component_demo_recording) %>
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

    attachment_recording = publishable.social_image_attachment_recording
    return if attachment_recording.blank?

    file_attachment = publishable.social_image_attachment&.file_attachment
    path = rails_blob_path(file_attachment, only_path: true) if file_attachment.present?

    if path.blank?
      begin
        # Prefer social-share sizing for link cards.
        path = recording_studio_attachable.attachment_preview_file_path(
          attachment_recording,
          variant_name: :social_share
        )
      rescue StandardError
        path = nil
      end
    end

    if path.blank?
      begin
        path = recording_studio_attachable.attachment_preview_file_path(
          attachment_recording,
          variant_name: :square_small
        )
      rescue StandardError
        path = nil
      end
    end

    return if path.blank?

    return path if path.to_s.match?(%r{\Ahttps?://}i)

    "#{request.base_url}#{path}"
  rescue StandardError
    nil
  end

  def header_tag_rows
    return [] unless @header_parent_recording && @header_publishable && @header_publishable_recording

    parse_header_tag_rows(@header_tag_code)
  end

  def header_publishability_rows
    return [] unless @header_parent_recording && @header_publishable && @header_publishable_recording

    [
      ["publishable_status", @header_publishable.status.to_s],
      ["currently_published", @header_publishable.currently_published?.to_s],
      ["scheduled_for_future", @header_publishable.scheduled_for_future?.to_s],
      ["publish_at", @header_publishable.publish_at&.iso8601.to_s.presence || "-"],
      ["unpublish_at", @header_publishable.unpublish_at&.iso8601.to_s.presence || "-"],
      ["seo_enabled", header_seo_enabled?.to_s]
    ]
  end

  def build_header_code_from_helper
    return "" unless @header_parent_recording && @header_publishable && @header_publishable_recording

    helpers.publishable_head_tags(
      publishable_recording: @header_publishable_recording,
      publishable: @header_publishable,
      public_url: @header_public_url
    ).to_s
  end

  def parse_header_tag_rows(tag_code)
    return [] if tag_code.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(tag_code)

    fragment.children.filter_map do |node|
      next if node.text?

      case node.name
      when "title"
        value = node.text.to_s.strip
        value.present? ? ["title", value] : nil
      when "meta"
        content = node["content"].to_s
        next if content.blank?

        if node["name"].present?
          ["meta[name=#{node['name']}]", content]
        elsif node["property"].present?
          ["meta[property=#{node['property']}]", content]
        end
      when "link"
        rel = node["rel"].to_s
        href = node["href"].to_s
        if rel.present? && href.present?
          ["link[rel=#{rel}]", href]
        end
      end
    end
  rescue StandardError
    []
  end

  def header_seo_enabled?
    recordable_type = @header_parent_recording&.recordable_type
    return true if recordable_type.blank?

    RecordingStudioPublishable.configuration.seo_enabled_for(recordable_type)
  rescue StandardError
    true
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
      RecordingStudioPublishable::Publishable.new(status: :published, slug: "scheduled-demo", publish_at: 1.day.from_now),
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
