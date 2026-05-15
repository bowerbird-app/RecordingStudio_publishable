# frozen_string_literal: true

require "active_support/concern"

module RecordingStudioPublishable
  module ParentRecordable
    extend ActiveSupport::Concern

    included do
      class_attribute :recording_studio_publishable_path_template,
                      instance_writer: false,
                      default: RecordingStudioPublishable::Configuration::DEFAULT_PUBLIC_PATH
    end

    class_methods do
      def recording_studio_publishable(
        path: RecordingStudioPublishable::Configuration::DEFAULT_PUBLIC_PATH,
        public_controller: nil,
        public_action: nil,
        public_layout: nil
      )
        self.recording_studio_publishable_path_template = path
        RecordingStudioPublishable.configuration.register_public_path(name, path: path)
        RecordingStudioPublishable.configuration.register_public_renderer(
          name,
          controller: public_controller,
          action: public_action,
          layout: public_layout
        )
      end

      def currently_published
        joins_publishable_scope.merge(RecordingStudioPublishable::Publishable.currently_published).distinct
      end

      def currently_live
        currently_published
      end

      def scheduled
        joins_publishable_scope.merge(RecordingStudioPublishable::Publishable.scheduled).distinct
      end

      def draft
        joins_publishable_scope.merge(RecordingStudioPublishable::Publishable.draft).distinct
      end

      def unpublished
        joins_publishable_scope.merge(RecordingStudioPublishable::Publishable.unpublished).distinct
      end

      private

      def joins_publishable_scope
        quoted_recordable_type = connection.quote(name)

        joins(publishable_scope_join_sql(quoted_recordable_type))
      end

      def publishable_scope_join_sql(quoted_recordable_type)
        <<~SQL.squish
          INNER JOIN recording_studio_recordings parent_recordings
            ON parent_recordings.recordable_type = #{quoted_recordable_type}
           AND parent_recordings.recordable_id = #{table_name}.id
          INNER JOIN recording_studio_recordings publishable_recordings
            ON publishable_recordings.parent_recording_id = parent_recordings.id
           AND publishable_recordings.recordable_type = 'RecordingStudioPublishable::Publishable'
           AND publishable_recordings.trashed_at IS NULL
          INNER JOIN recording_studio_publishable_publishables
            ON recording_studio_publishable_publishables.id = publishable_recordings.recordable_id
        SQL
      end
    end
  end
end
