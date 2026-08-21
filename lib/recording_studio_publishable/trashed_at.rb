# frozen_string_literal: true

module RecordingStudioPublishable
  # Soft-detects RecordingStudio Trashable's optional `trashed_at` column.
  # Publishable does not depend on Trashable; trash SQL is only emitted when the
  # column exists on `recording_studio_recordings`.
  module TrashedAt
    module_function

    def column?
      klass = recording_class
      return false unless klass
      return false unless klass.respond_to?(:table_exists?) && klass.table_exists?
      return false unless klass.respond_to?(:column_names)

      klass.column_names.include?("trashed_at")
    rescue StandardError
      false
    end

    def merge_active(attributes)
      column? ? attributes.merge(trashed_at: nil) : attributes
    end

    def active_sql(table_alias)
      return unless column?

      "#{table_alias}.trashed_at IS NULL"
    end

    def recording_class
      return unless defined?(RecordingStudio::Recording)

      RecordingStudio::Recording
    end
  end
end
