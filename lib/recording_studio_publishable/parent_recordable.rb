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

      private

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
  end
end
