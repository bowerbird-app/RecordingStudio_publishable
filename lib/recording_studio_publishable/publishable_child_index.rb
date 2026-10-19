# frozen_string_literal: true

module RecordingStudioPublishable
  # Repair text for the unique publishable-child index. Included so both
  # concurrent migrations print the same predicate, duplicate check, and steps.
  module PublishableChildIndexRepair
    UNIQUE_CHILD_INDEX = "index_rs_publishable_child_per_parent"
    RECORDABLE_TYPE = "RecordingStudioPublishable::Publishable"
    RECORDINGS = :recording_studio_recordings
    PARENT_COLUMN = "parent_recording_id"
    CONCURRENT_LOCK_TIMEOUT = "0"

    def duplicate_publishable_children_query
      <<~SQL.strip
        SELECT parent_recording_id, count(*)
        FROM #{connection.quote_table_name(RECORDINGS)}
        WHERE #{unique_child_index_where_clause}
        GROUP BY parent_recording_id
        HAVING count(*) > 1
      SQL
    end

    def unique_child_index_repair_steps
      <<~MSG
        Check for rows that would collide before rebuilding the unique index:

          #{duplicate_publishable_children_query};

        If the index is still present, drop it:

          DROP INDEX CONCURRENTLY #{schema_qualified_index_name(RECORDINGS, UNIQUE_CHILD_INDEX)};

        Then run:

          bin/rails db:migrate
      MSG
    end

    def unique_child_index_drift_message(index)
      <<~MSG
        #{UNIQUE_CHILD_INDEX} does not match the publishable child index.
        Expected a unique index on (#{PARENT_COLUMN}) WHERE #{unique_child_index_where_clause}.
        Found unique=#{index.unique} columns=#{Array(index.columns).inspect} where=#{index.where.inspect}.
        This migration will not drop a unique index it did not create in this run.
        #{unique_child_index_repair_steps}
      MSG
    end

    def preexisting_invalid_unique_child_index_message
      <<~MSG
        #{UNIQUE_CHILD_INDEX} is INVALID.
        A CREATE INDEX CONCURRENTLY failed and left this unique index behind.
        This migration will not drop a unique index it did not create in this run.
        #{unique_child_index_repair_steps}
      MSG
    end

    def invalid_index_created_by_this_run_message(error = nil)
      detail = error ? " PostgreSQL said: #{error.message.to_s.lines.first&.strip}." : ""
      <<~MSG
        #{UNIQUE_CHILD_INDEX} was created by this migration and left INVALID.#{detail}
        This migration dropped that invalid index concurrently.
        #{unique_child_index_repair_steps}
      MSG
    end

    def refuse_invalid_unique_child_index!
      index = find_index(RECORDINGS, UNIQUE_CHILD_INDEX)
      return unless index
      return if index.valid?

      raise preexisting_invalid_unique_child_index_message
    end
  end

  # Shape of the unique publishable-child index on the recordings table.
  module PublishableChildIndex
    include PublishableChildIndexRepair

    def unique_child_index_where_clause
      if column_exists?(RECORDINGS, :trashed_at)
        "recordable_type = '#{RECORDABLE_TYPE}' AND trashed_at IS NULL"
      else
        "recordable_type = '#{RECORDABLE_TYPE}'"
      end
    end

    def unique_child_index_shape?(index)
      index.unique &&
        Array(index.columns) == [PARENT_COLUMN] &&
        normalize_index_predicate(index.where) == normalize_index_predicate(unique_child_index_where_clause)
    end

    def find_index(table_name, index_name)
      connection.indexes(table_name).find { |candidate| candidate.name == index_name }
    end

    # connection.indexes follows the session search path.
    def index_valid?(table_name, index_name)
      connection.indexes(table_name).find { |candidate| candidate.name == index_name }&.valid?
    end

    def schema_qualified_index_name(table_name, index_name)
      schema = select_value(<<~SQL.squish)
        SELECT n.nspname
        FROM pg_class t
        INNER JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE t.relname = #{connection.quote(table_name.to_s)}
          AND n.nspname = ANY (current_schemas(false))
        ORDER BY array_position(current_schemas(false), n.nspname)
        LIMIT 1
      SQL
      "#{connection.quote_table_name(schema)}.#{connection.quote_table_name(index_name)}"
    end

    # 0 waits for older transactions. A short timeout cancels that wait.
    def with_concurrent_lock_timeout
      previous = select_value("SHOW lock_timeout")
      execute("SET lock_timeout = #{connection.quote(CONCURRENT_LOCK_TIMEOUT)}")
      yield
    ensure
      execute("SET lock_timeout = #{connection.quote(previous)}") if previous
    end

    def invalid_unique_child_index?
      index = find_index(RECORDINGS, UNIQUE_CHILD_INDEX)
      !index.nil? && !index.valid?
    end

    def drop_invalid_unique_child_index
      return unless invalid_unique_child_index?

      with_concurrent_lock_timeout do
        execute(<<~SQL.squish)
          DROP INDEX CONCURRENTLY #{schema_qualified_index_name(RECORDINGS, UNIQUE_CHILD_INDEX)}
        SQL
      end
    end

    private

    def normalize_index_predicate(predicate)
      strip_sql_casts(predicate.to_s).gsub(/[()]/, "").gsub(/\s+/, " ").strip
    end

    def strip_sql_casts(sql)
      sql.gsub(/'[^']*'|::(?:character\s+varying|double\s+precision|bit\s+varying|[\w.]+)/i) do |token|
        token.start_with?("'") ? token : ""
      end
    end
  end
end
