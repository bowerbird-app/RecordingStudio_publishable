# frozen_string_literal: true

class AddUniquePublishableChildIndexConcurrently < ActiveRecord::Migration[8.1]
  UNIQUE_CHILD_INDEX = "index_rs_publishable_child_per_parent"
  RECORDABLE_TYPE = "RecordingStudioPublishable::Publishable"
  RECORDINGS = :recording_studio_recordings
  SHORT_LOCK_TIMEOUT = "5s"

  disable_ddl_transaction!

  def up
    refuse_invalid_unique_child_index!
    return if index_exists?(RECORDINGS, name: UNIQUE_CHILD_INDEX)

    with_short_lock_timeout do
      add_index RECORDINGS,
                :parent_recording_id,
                unique: true,
                name: UNIQUE_CHILD_INDEX,
                where: unique_child_index_where_clause,
                algorithm: :concurrently,
                if_not_exists: true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, <<~MSG.squish
      Refusing to drop unique index #{UNIQUE_CHILD_INDEX}.
      Hosts that already installed Publishable created it inside the
      publishables table migration. Dropping it would allow two publishable
      children under one parent.
    MSG
  end

  private

  def unique_child_index_where_clause
    if column_exists?(RECORDINGS, :trashed_at)
      "recordable_type = '#{RECORDABLE_TYPE}' AND trashed_at IS NULL"
    else
      "recordable_type = '#{RECORDABLE_TYPE}'"
    end
  end

  # A failed CREATE INDEX CONCURRENTLY leaves the index in place with
  # pg_index.indisvalid = false. IF NOT EXISTS would then skip the rebuild.
  # Do not drop the unique index from here. Rebuild it concurrently:
  #
  #   SET lock_timeout = '5s';
  #   DROP INDEX CONCURRENTLY index_rs_publishable_child_per_parent;
  #   -- re-run db:migrate so this migration can CREATE UNIQUE INDEX CONCURRENTLY
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
          WHERE #{unique_child_index_where_clause};
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
