# frozen_string_literal: true

module RecordingStudioPublishable
  # Host copies of the concurrent migrations include V1. Leave this module
  # frozen. A later change to the index ships as V2 and a new migration.
  module PublishableChildIndex
    module V1
      # Repair text shared by the concurrent migrations.
      module Repair
        UNIQUE_CHILD_INDEX = "index_rs_publishable_child_per_parent"
        RECORDABLE_TYPE = "RecordingStudioPublishable::Publishable"
        RECORDINGS = :recording_studio_recordings
        PARENT_COLUMN = "parent_recording_id"
        CONCURRENT_LOCK_TIMEOUT = "0"
        CONCURRENT_STATEMENT_TIMEOUT = "0"

        def duplicate_publishable_children_query
          <<~SQL.strip
            SELECT parent_recording_id, count(*)
            FROM #{schema_qualified_table_name(RECORDINGS)}
            WHERE #{unique_child_index_where_clause}
            GROUP BY parent_recording_id
            HAVING count(*) > 1
          SQL
        end

        def unique_child_index_repair_steps(index_name = UNIQUE_CHILD_INDEX)
          <<~MSG
            Check for rows that would collide before rebuilding the unique index:

              #{duplicate_publishable_children_query};

            If the index is still present, drop it:

              DROP INDEX CONCURRENTLY #{schema_qualified_index_name(RECORDINGS, index_name)};

            Then run:

              bin/rails db:migrate
          MSG
        end

        def unique_child_index_drift_message(index)
          <<~MSG
            #{index.name} does not match the publishable child index.
            Expected a unique index on (#{PARENT_COLUMN}) WHERE #{unique_child_index_where_clause}.
            Found unique=#{index.unique} columns=#{Array(index.columns).inspect} where=#{index.where.inspect}.
            This migration will not drop an index it did not create in this run.
            #{unique_child_index_repair_steps(index.name)}
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
          built_index_invalid_message(UNIQUE_CHILD_INDEX, error)
        end

        def built_index_invalid_message(index_name, error = nil)
          detail = error ? " PostgreSQL said: #{error.message.to_s.lines.first&.strip}." : ""
          kept = ""
          if index_name != UNIQUE_CHILD_INDEX
            kept = "The existing unique index #{UNIQUE_CHILD_INDEX} is still in place.\n"
          end
          <<~MSG
            #{index_name} was created by this migration and left INVALID.#{detail}
            This migration dropped that invalid index concurrently.
            #{kept}#{unique_child_index_repair_steps(index_name)}
          MSG
        end

        def refuse_invalid_unique_child_index!
          index = find_index(RECORDINGS, UNIQUE_CHILD_INDEX)
          return unless index
          return if index.valid?

          raise preexisting_invalid_unique_child_index_message
        end
      end

      include Repair

      def unique_child_index_where_clause
        if column_exists?(RECORDINGS, :trashed_at)
          "#{stricter_unique_child_predicate} AND trashed_at IS NULL"
        else
          stricter_unique_child_predicate
        end
      end

      # The index built before trashed_at existed. It covers every publishable
      # child, including trashed ones, so it is stricter than the current predicate.
      def stricter_unique_child_predicate
        "recordable_type = '#{RECORDABLE_TYPE}'"
      end

      def stricter_unique_child_shape?(index)
        return false unless column_exists?(RECORDINGS, :trashed_at)
        return false unless index.unique
        return false unless Array(index.columns) == [PARENT_COLUMN]

        normalize_index_predicate(index.where) == normalize_index_predicate(stricter_unique_child_predicate)
      end

      def stricter_unique_child_index?(index)
        index.valid? && stricter_unique_child_shape?(index)
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

      def schema_qualified_table_name(table_name)
        "#{connection.quote_table_name(schema_name_for(table_name))}." \
          "#{connection.quote_table_name(table_name)}"
      end

      def schema_qualified_index_name(table_name, index_name)
        "#{connection.quote_table_name(schema_name_for(table_name))}." \
          "#{connection.quote_table_name(index_name)}"
      end

      # 0 waits. A short lock_timeout or statement_timeout cancels that wait
      # and can leave an INVALID index behind.
      def with_concurrent_lock_timeout
        previous_lock_timeout = select_value("SHOW lock_timeout")
        previous_statement_timeout = select_value("SHOW statement_timeout")
        execute("SET lock_timeout = #{connection.quote(CONCURRENT_LOCK_TIMEOUT)}")
        execute("SET statement_timeout = #{connection.quote(CONCURRENT_STATEMENT_TIMEOUT)}")
        yield
      ensure
        execute("SET statement_timeout = #{connection.quote(previous_statement_timeout)}") if previous_statement_timeout
        execute("SET lock_timeout = #{connection.quote(previous_lock_timeout)}") if previous_lock_timeout
      end

      def invalid_index?(index_name)
        index = find_index(RECORDINGS, index_name)
        !index.nil? && !index.valid?
      end

      def drop_invalid_index(index_name)
        return unless invalid_index?(index_name)

        with_concurrent_lock_timeout do
          execute("DROP INDEX CONCURRENTLY #{schema_qualified_index_name(RECORDINGS, index_name)}")
        end
      end

      def invalid_unique_child_index?
        invalid_index?(UNIQUE_CHILD_INDEX)
      end

      def drop_invalid_unique_child_index
        drop_invalid_index(UNIQUE_CHILD_INDEX)
      end

      private

      def schema_name_for(table_name)
        select_value(<<~SQL.squish)
          SELECT n.nspname
          FROM pg_class t
          INNER JOIN pg_namespace n ON n.oid = t.relnamespace
          WHERE t.relname = #{connection.quote(table_name.to_s)}
            AND n.nspname = ANY (current_schemas(false))
          ORDER BY array_position(current_schemas(false), n.nspname)
          LIMIT 1
        SQL
      end

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
end
