# frozen_string_literal: true

class DropDuplicatePublishableStatusIndex < ActiveRecord::Migration[8.1]
  # Created with the publishables table. Fresh installs keep this index.
  ORIGINAL_INDEX = "index_rs_publishables_on_state_window"
  # Added by 20260516000100 on the same columns and options. Never drop ORIGINAL_INDEX.
  DUPLICATE_INDEX = "index_publishables_on_status_and_publish_times"
  UNIQUE_CHILD_INDEX = "index_rs_publishable_child_per_parent"
  PUBLISHABLES = :recording_studio_publishable_publishables
  RECORDINGS = :recording_studio_recordings
  STATUS_COLUMNS = %w[status publish_at unpublish_at].freeze
  SHORT_LOCK_TIMEOUT = "5s"

  disable_ddl_transaction!

  def up
    refuse_invalid_unique_child_index!
    return unless original_status_index_valid?
    return unless index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)

    with_short_lock_timeout do
      remove_index PUBLISHABLES,
                   name: DUPLICATE_INDEX,
                   algorithm: :concurrently,
                   if_exists: true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, <<~MSG
      Refusing to recreate duplicate index #{DUPLICATE_INDEX}.
      #{ORIGINAL_INDEX} is the index this migration keeps.
      Putting the duplicate back would add a second identical index on a live table.
      Recreate it concurrently only if you have a reason to:

        SET lock_timeout = '5s';
        CREATE INDEX CONCURRENTLY IF NOT EXISTS #{DUPLICATE_INDEX}
          ON recording_studio_publishable_publishables (status, publish_at, unpublish_at);
    MSG
  end

  private

  def original_status_index_valid?
    index = connection.indexes(PUBLISHABLES).find { |candidate| candidate.name == ORIGINAL_INDEX }
    return false unless index
    return false unless index.columns.map(&:to_s) == STATUS_COLUMNS
    return false if index.unique || index.where.present?

    index_valid?(PUBLISHABLES, ORIGINAL_INDEX)
  end

  def refuse_invalid_unique_child_index!
    return unless index_exists?(RECORDINGS, name: UNIQUE_CHILD_INDEX)
    return if index_valid?(RECORDINGS, UNIQUE_CHILD_INDEX)

    raise <<~MSG
      #{UNIQUE_CHILD_INDEX} is INVALID.
      A CREATE INDEX CONCURRENTLY failed and left this unique index behind.
      This migration will not drop a unique index.
      Rebuild it concurrently, then run db:migrate again:

        SET lock_timeout = '5s';
        DROP INDEX CONCURRENTLY #{UNIQUE_CHILD_INDEX};
        CREATE UNIQUE INDEX CONCURRENTLY #{UNIQUE_CHILD_INDEX}
          ON recording_studio_recordings (parent_recording_id)
          WHERE recordable_type = 'RecordingStudioPublishable::Publishable' AND trashed_at IS NULL;

      If recording_studio_recordings has no trashed_at column, omit "AND trashed_at IS NULL".
    MSG
  end

  def index_valid?(table_name, index_name)
    value = select_value(<<~SQL.squish)
      SELECT pg_index.indisvalid
      FROM pg_index
      INNER JOIN pg_class index_class ON index_class.oid = pg_index.indexrelid
      INNER JOIN pg_class table_class ON table_class.oid = pg_index.indrelid
      INNER JOIN pg_namespace ON pg_namespace.oid = index_class.relnamespace
      WHERE index_class.relname = #{connection.quote(index_name)}
        AND table_class.relname = #{connection.quote(table_name)}
        AND pg_namespace.nspname = current_schema()
    SQL
    ActiveRecord::Type::Boolean.new.cast(value) == true
  end

  def with_short_lock_timeout
    previous = select_value("SHOW lock_timeout")
    execute("SET lock_timeout = #{connection.quote(SHORT_LOCK_TIMEOUT)}")
    yield
  ensure
    execute("SET lock_timeout = #{connection.quote(previous)}") if previous
  end
end
