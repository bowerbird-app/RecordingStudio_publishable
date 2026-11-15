# frozen_string_literal: true

module RecordingStudioPublishable
  module PublishRules
    PUBLISHABLE_TYPE = "RecordingStudioPublishable::Publishable"

    class << self
      def newest_kept_parent(recordable)
        return if recordable.nil? || recordable.id.blank?

        RecordingStudio::Recording.kept.where(
          recordable_type: recordable.class.name,
          recordable_id: recordable.id
        ).order(:created_at, :id).last
      end

      def hides_from_index?(meta_robots)
        meta_robots.to_s.match?(/noindex/i)
      end

      def allow_index_sql
        column = "#{publishables_table}.meta_robots"

        <<~SQL.squish
          #{column} IS NULL
          OR BTRIM(#{column}) = ''
          OR #{column} NOT ILIKE '%noindex%'
        SQL
      end

      def allow_canonical_sql
        column = "#{publishables_table}.canonical_url"
        trimmed = "BTRIM(#{column})"

        <<~SQL.squish
          #{column} IS NULL
          OR #{trimmed} = ''
          OR (
            #{trimmed} !~ '[[:space:]]'
            AND (
              #{trimmed} LIKE '/%'
              OR #{trimmed} ~* '^https?://[^[:space:]/?#]+'
            )
          )
        SQL
      end

      def recordable_join_sql(model, quoted_type:)
        connection = model.connection
        recordings = connection.quote_table_name(RecordingStudio::Recording.table_name)
        table = connection.quote_table_name(model.table_name)
        parent = newest_parent_sql(recordings, table, quoted_type)

        "#{parent} #{kept_child_join(recordings, 'parent_recordings.id')}"
      end

      def recording_child_join_sql(relation)
        model = relation.respond_to?(:klass) ? relation.klass : relation
        recordings = model.connection.quote_table_name(model.table_name)

        kept_child_join(recordings, "#{recordings}.id")
      end

      private

      def newest_parent_sql(recordings, table, quoted_type)
        kept = RecordingStudio.kept_sql("parent_recordings")
        [
          "INNER JOIN LATERAL (",
          "SELECT parent_recordings.id FROM #{recordings} parent_recordings",
          "WHERE parent_recordings.recordable_type = #{quoted_type}",
          "AND parent_recordings.recordable_id = #{table}.id AND #{kept}",
          "ORDER BY parent_recordings.created_at DESC, parent_recordings.id DESC",
          "LIMIT 1) parent_recordings ON TRUE"
        ].join(" ")
      end

      def kept_child_join(recordings, parent_id_sql)
        kept = RecordingStudio.kept_sql("publishable_recordings")
        type_sql = RecordingStudio::Recording.connection.quote(PUBLISHABLE_TYPE)
        [
          "INNER JOIN LATERAL (SELECT publishable_recordings.recordable_id",
          "FROM #{recordings} publishable_recordings",
          "WHERE publishable_recordings.parent_recording_id = #{parent_id_sql}",
          "AND publishable_recordings.recordable_type = #{type_sql} AND #{kept}",
          "ORDER BY publishable_recordings.id ASC LIMIT 1) publishable_recordings ON TRUE",
          child_publishable_join
        ].join(" ")
      end

      def child_publishable_join
        publishables = publishables_table
        "INNER JOIN #{publishables} ON #{publishables}.id = publishable_recordings.recordable_id"
      end

      def publishables_table
        RecordingStudioPublishable::Publishable.quoted_table_name
      end
    end
  end
end
