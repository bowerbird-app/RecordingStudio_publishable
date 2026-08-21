# frozen_string_literal: true

require "active_support/concern"

module RecordingStudioPublishable
  module ParentRecordable
    extend ActiveSupport::Concern

    included do
      class_attribute :recording_studio_publishable_path_template,
                      :recording_studio_publishable_schedule_enabled,
                      :recording_studio_publishable_seo_enabled,
                      instance_writer: false,
                      default: RecordingStudioPublishable::Configuration::DEFAULT_PUBLIC_PATH

      self.recording_studio_publishable_schedule_enabled = true
      self.recording_studio_publishable_seo_enabled = true
    end

    class_methods do
      def configure_publishable!(
        path: RecordingStudioPublishable::Configuration::DEFAULT_PUBLIC_PATH,
        public_controller: nil,
        public_action: nil,
        public_layout: nil,
        schedule: true,
        seo: true,
        **
      )
        configured_path = RecordingStudioPublishable.configuration.public_path_for(name)
        effective_path = path
        if path == RecordingStudioPublishable::Configuration::DEFAULT_PUBLIC_PATH &&
           configured_path != RecordingStudioPublishable::Configuration::DEFAULT_PUBLIC_PATH
          effective_path = configured_path
        end

        self.recording_studio_publishable_path_template = effective_path
        self.recording_studio_publishable_schedule_enabled = schedule != false
        self.recording_studio_publishable_seo_enabled = seo != false

        RecordingStudioPublishable.configuration.register_public_renderer(
          name,
          controller: public_controller,
          action: public_action,
          layout: public_layout,
          path: effective_path
        )
      end

      def published
        joins_publishable_scope.merge(RecordingStudioPublishable::Publishable.currently_published).distinct
      end

      def published_in(range_or_time)
        return none if range_or_time.blank?

        publish_window = range_or_time.is_a?(Range) ? range_or_time : (Time.current..range_or_time)

        published.where(recording_studio_publishable_publishables: { publish_at: publish_window })
      end

      def scheduled
        joins_publishable_scope.merge(RecordingStudioPublishable::Publishable.scheduled).distinct
      end

      def scheduled_in(range_or_time)
        return none if range_or_time.blank?

        publish_window = range_or_time.is_a?(Range) ? range_or_time : (Time.current..range_or_time)

        scheduled.where(recording_studio_publishable_publishables: { publish_at: publish_window })
      end

      def draft
        joins_publishable_scope.merge(RecordingStudioPublishable::Publishable.draft).distinct
      end

      def unpublished
        joins_publishable_scope.merge(RecordingStudioPublishable::Publishable.unpublished).distinct
      end

      def unpublished_in(range_or_time)
        return none if range_or_time.blank?

        unpublish_window = range_or_time.is_a?(Range) ? range_or_time : (Time.current..range_or_time)

        unpublished.where(recording_studio_publishable_publishables: { unpublish_at: unpublish_window })
      end

      def indexable
        indexable_join_scope.merge(indexable_robots_scope).merge(indexable_url_scope)
      end

      def indexable_url?(url)
        return false if url.blank?

        value = url.to_s.strip
        return true if value.start_with?("/")

        uri = URI.parse(value)
        %w[http https].include?(uri.scheme) && uri.host.present?
      rescue URI::InvalidURIError
        false
      end

      private

      def indexable_join_scope
        quoted_recordable_type = connection.quote(name)
        joins(indexable_scope_join_sql(quoted_recordable_type)).distinct
      end

      def indexable_robots_scope
        RecordingStudioPublishable::Publishable.currently_published.where(<<~SQL.squish, noindex: "%noindex%")
          recording_studio_publishable_publishables.meta_robots IS NULL
          OR BTRIM(recording_studio_publishable_publishables.meta_robots) = ''
          OR recording_studio_publishable_publishables.meta_robots NOT ILIKE :noindex
        SQL
      end

      def indexable_url_scope
        RecordingStudioPublishable::Publishable.where(<<~SQL.squish)
          recording_studio_publishable_publishables.canonical_url IS NULL
          OR BTRIM(recording_studio_publishable_publishables.canonical_url) = ''
          OR recording_studio_publishable_publishables.canonical_url LIKE '/%'
          OR recording_studio_publishable_publishables.canonical_url ILIKE 'http://%'
          OR recording_studio_publishable_publishables.canonical_url ILIKE 'https://%'
        SQL
      end

      def indexable_scope_join_sql(quoted_recordable_type)
        child_trash_sql = RecordingStudioPublishable::TrashedAt.active_sql("publishable_recordings")
        parent_trash_sql = RecordingStudioPublishable::TrashedAt.active_sql("parent_recordings")
        child_trash_clause = child_trash_sql ? "AND #{child_trash_sql}" : ""
        parent_trash_clause = parent_trash_sql ? "AND #{parent_trash_sql}" : ""
        recordable_trash_clause = recordable_trashed_at_sql

        <<~SQL.squish
          INNER JOIN recording_studio_recordings parent_recordings
            ON parent_recordings.recordable_type = #{quoted_recordable_type}
           AND parent_recordings.recordable_id = #{table_name}.id
           #{parent_trash_clause}
          INNER JOIN recording_studio_recordings publishable_recordings
            ON publishable_recordings.parent_recording_id = parent_recordings.id
           AND publishable_recordings.recordable_type = 'RecordingStudioPublishable::Publishable'
           #{child_trash_clause}
          INNER JOIN recording_studio_publishable_publishables
            ON recording_studio_publishable_publishables.id = publishable_recordings.recordable_id
          #{recordable_trash_clause}
        SQL
      end

      def recordable_trashed_at_sql
        return "" unless column_names.include?("trashed_at")

        "AND #{table_name}.trashed_at IS NULL"
      rescue StandardError
        ""
      end

      def joins_publishable_scope
        quoted_recordable_type = connection.quote(name)

        joins(publishable_scope_join_sql(quoted_recordable_type))
      end

      def publishable_scope_join_sql(quoted_recordable_type)
        trash_sql = RecordingStudioPublishable::TrashedAt.active_sql("publishable_recordings")
        trash_clause = trash_sql ? "AND #{trash_sql}" : ""

        <<~SQL.squish
          INNER JOIN recording_studio_recordings parent_recordings
            ON parent_recordings.recordable_type = #{quoted_recordable_type}
           AND parent_recordings.recordable_id = #{table_name}.id
          INNER JOIN recording_studio_recordings publishable_recordings
            ON publishable_recordings.parent_recording_id = parent_recordings.id
           AND publishable_recordings.recordable_type = 'RecordingStudioPublishable::Publishable'
           #{trash_clause}
          INNER JOIN recording_studio_publishable_publishables
            ON recording_studio_publishable_publishables.id = publishable_recordings.recordable_id
        SQL
      end
    end

    def self.configure!(base, **options)
      base.configure_publishable!(**options)
    end

    def published?
      self.class.published.where(id: id).exists?
    end

    def draft?
      self.class.draft.where(id: id).exists?
    end

    def scheduled?
      self.class.scheduled.where(id: id).exists?
    end

    def unpublished?
      self.class.unpublished.where(id: id).exists?
    end

    def indexable?
      self.class.indexable.where(id: id).exists? && indexable_url.present?
    end

    def indexable_url
      return unless published?

      publishable = current_publishable_for_index
      return if publishable.blank?
      return if publishable.noindex?

      url = publishable.canonical_url.presence || published_url
      url if self.class.indexable_url?(url)
    end

    def published_url
      return @published_url if instance_variable_defined?(:@published_url)

      @published_url = begin
        parent_recording = RecordingStudio::Recording.where(
          RecordingStudioPublishable::TrashedAt.merge_active(
            recordable_type: self.class.name,
            recordable_id: id
          )
        ).order(:created_at, :id).last
        if parent_recording.present?
          publishable_recording = if parent_recording.respond_to?(:publishable_child_recording)
                                    parent_recording.publishable_child_recording
                                  end
          publishable = publishable_recording&.recordable

          if publishable.present? && publishable.currently_published?
            RecordingStudioPublishable::Routing.url_for(
              publishable_recording: publishable_recording,
              publishable: publishable,
              parent_recordable_type: self.class.name
            )
          end
        end
      rescue StandardError
        nil
      end
    end

    def current_publishable_for_index
      parent_recording = RecordingStudio::Recording.where(
        RecordingStudioPublishable::TrashedAt.merge_active(
          recordable_type: self.class.name,
          recordable_id: id
        )
      ).order(:created_at, :id).last
      return if parent_recording.blank?

      if parent_recording.respond_to?(:current_publishable)
        parent_recording.current_publishable
      else
        parent_recording.publishable_child_recording&.recordable
      end
    rescue StandardError
      nil
    end
  end
end
