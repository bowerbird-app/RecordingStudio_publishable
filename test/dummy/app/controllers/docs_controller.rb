# frozen_string_literal: true

class DocsController < ApplicationController
  def install; end

  def configuration
    render :config
  end

  def setup; end

  def recordable_types
    @recordable_types = RecordingStudio::RecordableTypesService.filtered_types
  end

  def recordings_tree
    recordings = RecordingStudio::Recording.reorder(:created_at, :id).to_a
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
        title: "Recordable.published",
        subtitle: "Returns Recordable records whose publishable child is currently live.",
        code: <<~RUBY
          Recordable.published

          # Chain regular ActiveRecord filters on the returned Recordable relation.
          Recordable.published.where("recordables.updated_at >= ?", 30.days.ago)
          Recordable.published.where(author_id: current_user.id)

          # Optional publish_at window filter on published records.
          # Range input
          Recordable.published_in(2.weeks.ago..Time.current)

          # Time cutoff input (interpreted as Time.current..cutoff)
          Recordable.published_in(1.week.from_now)
        RUBY
      },
      {
        title: "Recordable.scheduled",
        subtitle: "Returns Recordable records whose publishable child is scheduled in the future.",
        code: <<~RUBY
          Recordable.scheduled

          # Add host-model filters by chaining where clauses.
          Recordable.scheduled.where("recordables.updated_at >= ?", 30.days.ago)
          Recordable.scheduled.where(author_id: current_user.id)

          # Optional publish_at window filter on scheduled records.
          # Range input
          Recordable.scheduled_in(Time.current..2.weeks.from_now)

          # Time cutoff input (interpreted as Time.current..cutoff)
          Recordable.scheduled_in(2.weeks.from_now)
        RUBY
      },
      {
        title: "Recordable.draft",
        subtitle: "Returns Recordable records whose publishable child is still in draft.",
        code: <<~RUBY
          Recordable.draft
        RUBY
      },
      {
        title: "Recordable.unpublished",
        subtitle: "Returns Recordable records whose publishable child has been unpublished.",
        code: <<~RUBY
          Recordable.unpublished

          # Optional unpublish_at window filter on unpublished records.
          # Range input
          Recordable.unpublished_in(Time.current..2.weeks.from_now)

          # Time cutoff input (interpreted as Time.current..cutoff)
          Recordable.unpublished_in(2.weeks.from_now)
        RUBY
      },
      {
        title: "Recordable.indexable",
        subtitle: "Returns live pages that search can list: published, not hidden from search, and with a public URL.",
        code: <<~RUBY
          Recordable.indexable

          recordable = Recordable.find(recordable_id)
          recordable.indexable?
        RUBY
      },
      {
        title: "recordable.published?",
        subtitle: "Checks whether one Recordable record is currently published.",
        code: <<~RUBY
          recordable = Recordable.find(recordable_id)
          recordable.published?
        RUBY
      },
      {
        title: "recordable.scheduled?",
        subtitle: "Checks whether one Recordable record is scheduled for future publish.",
        code: <<~RUBY
          recordable = Recordable.find(recordable_id)
          recordable.scheduled?
        RUBY
      },
      {
        title: "recordable.draft?",
        subtitle: "Checks whether one Recordable record is in draft state.",
        code: <<~RUBY
          recordable = Recordable.find(recordable_id)
          recordable.draft?
        RUBY
      },
      {
        title: "recordable.unpublished?",
        subtitle: "Checks whether one Recordable record was previously published and is now unpublished.",
        code: <<~RUBY
          recordable = Recordable.find(recordable_id)
          recordable.unpublished?
        RUBY
      },
      {
        title: "RecordingStudioPublishable.configuration.schedule_enabled_for(\"Recordable\")",
        subtitle: "Returns whether schedule controls are enabled for Recordable recordables.",
        code: <<~RUBY
          RecordingStudioPublishable.configuration.schedule_enabled_for("Recordable")
        RUBY
      },
      {
        title: "RecordingStudioPublishable.configuration.seo_enabled_for(\"Recordable\")",
        subtitle: "Returns whether SEO-specific behavior is enabled for Recordable recordables.",
        code: <<~RUBY
          RecordingStudioPublishable.configuration.seo_enabled_for("Recordable")
        RUBY
      },
      {
        title: "Recordable.published_url",
        subtitle: "Returns the canonical published URL path for one Recordable, or nil when it is not currently published.",
        code: <<~RUBY
          recordable = Recordable.find(recordable_id)

          # Returns a canonical path like /published/:uuid/:slug when published.
          recordable.published_url

          # Returns nil when the recordable is not currently published.
          recordable.published_url # => nil
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
      ["seo_enabled", header_seo_enabled?.to_s],
      ["indexable", header_indexable?.to_s],
      ["robots", @header_publishable.robots_value.to_s]
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

  def header_indexable?
    recordable = @header_parent_recording&.recordable
    recordable.respond_to?(:indexable?) && recordable.indexable?
  rescue StandardError
    false
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
    identifier = recordable_identifier(safe_recordable_for(recording))

    "#{type_label}: #{identifier}"
  end

  def safe_recordable_for(recording)
    recording.recordable
  rescue NameError
    nil
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
