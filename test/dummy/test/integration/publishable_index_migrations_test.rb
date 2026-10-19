# frozen_string_literal: true

require "test_helper"
require "pg"

class PublishableIndexMigrationsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  GEM_MIGRATIONS = Rails.root.join("../..", "db/migrate").expand_path
  ORIGINAL_INDEX = "index_rs_publishables_on_state_window"
  DUPLICATE_INDEX = "index_publishables_on_status_and_publish_times"
  UNIQUE_INDEX = "index_rs_publishable_child_per_parent"
  PUBLISHABLES = :recording_studio_publishable_publishables
  RECORDINGS = :recording_studio_recordings
  STATUS_COLUMNS = %w[status publish_at unpublish_at].freeze
  ALREADY_RAN = %w[20250101000001 20260515000100 20260516000100].freeze
  UNIQUE_SQL = <<~SQL.squish
    CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS "index_rs_publishable_child_per_parent"
    ON "recording_studio_recordings" ("parent_recording_id")
    WHERE recordable_type = 'RecordingStudioPublishable::Publishable' AND trashed_at IS NULL
  SQL
  DROP_SQL = 'DROP INDEX CONCURRENTLY "index_publishables_on_status_and_publish_times"'

  setup do
    @original_config = ActiveRecord::Base.connection_db_config
    @verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    @scratch = "publishable_index_migrations"
    with_original_connection do
      drop_scratch_database
      ActiveRecord::Base.connection.create_database(@scratch)
    end
    ActiveRecord::Base.establish_connection(scratch_config)
    ActiveRecord::Base.connection.enable_extension("pgcrypto")
    load_gem_migrations
  end

  teardown do
    ActiveRecord::Migration.verbose = @verbose if defined?(@verbose)
    restore_original_connection
    drop_scratch_database
  end

  test "fresh install creates each index once and the unique index is valid" do
    create_recordings_table
    connection.execute("SET lock_timeout = '4s'")
    previous_timeout = connection.select_value("SHOW lock_timeout")

    sql, open_transactions = capture_sql { migration_context.migrate }
    joined = sql.join("\n")

    assert_equal [ORIGINAL_INDEX], status_index_names
    assert_not connection.index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)
    assert connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
    assert index_valid?(RECORDINGS, UNIQUE_INDEX)
    assert_includes joined, UNIQUE_SQL
    refute_includes joined, DUPLICATE_INDEX
    assert_includes joined, "SET lock_timeout = '0'"
    assert_includes joined, "SET statement_timeout = '0'"
    refute_includes joined, "5s"
    assert open_transactions.any?, "expected a concurrent statement"
    assert_equal [0], open_transactions.uniq
    assert_equal previous_timeout, connection.select_value("SHOW lock_timeout")

    second, = capture_sql { migration_context.migrate }
    refute_includes second.join("\n"), "CREATE UNIQUE INDEX"
    refute_includes second.join("\n"), "DROP INDEX"
    refute_includes second.join("\n"), "SET lock_timeout"
    refute_includes second.join("\n"), "SET statement_timeout"

    third, = capture_sql { AddUniquePublishableChildIndexConcurrently.new.migrate(:up) }
    refute_includes third.join("\n"), "SET lock_timeout"
    assert_equal [ORIGINAL_INDEX], status_index_names
    assert index_valid?(RECORDINGS, UNIQUE_INDEX)
  end

  test "already-ran hosts drop the duplicate and keep the original index" do
    v090_sql, = capture_sql { install_already_ran_schema }
    v090 = v090_sql.join("\n")
    assert_match(/CREATE UNIQUE INDEX "#{UNIQUE_INDEX}"/, v090)
    refute_match(/CREATE UNIQUE INDEX CONCURRENTLY/, v090)
    assert_includes v090, DUPLICATE_INDEX

    sql, open_transactions = capture_sql { migrate_pending_after(ALREADY_RAN) }
    joined = sql.join("\n")

    assert_equal [ORIGINAL_INDEX], status_index_names
    assert index_valid?(PUBLISHABLES, ORIGINAL_INDEX)
    assert_not connection.index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)
    assert index_valid?(RECORDINGS, UNIQUE_INDEX)
    assert_includes joined, DROP_SQL
    assert_includes joined, "SET lock_timeout = '0'"
    refute_includes joined, "5s"
    refute_includes joined, "DROP INDEX CONCURRENTLY \"#{ORIGINAL_INDEX}\""
    refute_includes joined, "DROP INDEX CONCURRENTLY \"#{UNIQUE_INDEX}\""
    refute_includes joined, "CREATE UNIQUE INDEX"
    assert_equal [0], open_transactions.uniq

    capture_sql { DropDuplicatePublishableStatusIndex.new.migrate(:up) }
    assert_equal [ORIGINAL_INDEX], status_index_names
    assert index_valid?(RECORDINGS, UNIQUE_INDEX)

    error = assert_raises(ActiveRecord::IrreversibleMigration) do
      DropDuplicatePublishableStatusIndex.new.migrate(:down)
    end
    assert_match(/CONCURRENTLY/, error.message)
    assert_match(/#{ORIGINAL_INDEX}/, error.message)
    assert_equal [ORIGINAL_INDEX], status_index_names
  end

  test "status index migration is idempotent and skips an equivalent index" do
    create_publishables_table
    connection.add_index PUBLISHABLES, STATUS_COLUMNS, name: ORIGINAL_INDEX

    skipped, = capture_sql { AddIndexesToPublishable.new.migrate(:up) }
    refute_includes skipped.join("\n"), DUPLICATE_INDEX
    assert_equal [ORIGINAL_INDEX], status_index_names

    connection.remove_index PUBLISHABLES, name: ORIGINAL_INDEX
    AddIndexesToPublishable.new.migrate(:up)
    assert_equal [DUPLICATE_INDEX], status_index_names
    AddIndexesToPublishable.new.migrate(:up)
    assert_equal [DUPLICATE_INDEX], status_index_names
  end

  test "invalid unique index is reported and is not dropped" do
    install_already_ran_schema
    mark_index_invalid(UNIQUE_INDEX)

    error = assert_raises(RuntimeError) do
      AddUniquePublishableChildIndexConcurrently.new.migrate(:up)
    end
    assert_match(/INVALID/, error.message)
    assert_match(/will not drop a unique index/, error.message)
    assert_match(/DROP INDEX CONCURRENTLY "[\w.]+"\."#{UNIQUE_INDEX}"/, error.message)
    assert_match(/HAVING count\(\*\) > 1/, error.message)
    assert_match(%r{bin/rails db:migrate}, error.message)
    refute_match(/lock_timeout/i, error.message)
    assert connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
    assert_not index_valid?(RECORDINGS, UNIQUE_INDEX)
    assert connection.index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)

    cleanup_error = assert_raises(RuntimeError) do
      DropDuplicatePublishableStatusIndex.new.migrate(:up)
    end
    assert_match(/will not drop a unique index/, cleanup_error.message)
    assert connection.index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)
    assert connection.index_exists?(PUBLISHABLES, name: ORIGINAL_INDEX)
    assert connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
  end

  test "duplicate stays when the original index is missing or invalid" do
    create_recordings_table
    create_publishables_table
    add_unique_child_index
    connection.add_index PUBLISHABLES, STATUS_COLUMNS, name: DUPLICATE_INDEX

    DropDuplicatePublishableStatusIndex.new.migrate(:up)
    assert connection.index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)
    assert_not connection.index_exists?(PUBLISHABLES, name: ORIGINAL_INDEX)

    connection.add_index PUBLISHABLES, STATUS_COLUMNS, name: ORIGINAL_INDEX
    mark_index_invalid(ORIGINAL_INDEX)
    DropDuplicatePublishableStatusIndex.new.migrate(:up)
    assert connection.index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)
    assert connection.index_exists?(PUBLISHABLES, name: ORIGINAL_INDEX)
    assert index_valid?(RECORDINGS, UNIQUE_INDEX)
  end

  test "equivalent status index ignores expression indexes and extra options" do
    create_publishables_table
    connection.execute(<<~SQL)
      CREATE INDEX index_publishables_lower_status
      ON recording_studio_publishable_publishables ((lower(status)))
    SQL
    connection.add_index PUBLISHABLES, STATUS_COLUMNS,
                         name: "index_publishables_status_desc",
                         order: { status: :desc }
    connection.add_index PUBLISHABLES, STATUS_COLUMNS,
                         name: "index_publishables_status_where",
                         where: "status IS NOT NULL"

    assert_nothing_raised { AddIndexesToPublishable.new.migrate(:up) }
    assert connection.index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)

    connection.remove_index PUBLISHABLES, name: DUPLICATE_INDEX
    connection.add_index PUBLISHABLES, STATUS_COLUMNS, name: ORIGINAL_INDEX
    AddIndexesToPublishable.new.migrate(:up)
    assert_not connection.index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)
  end

  test "unique index omits trashed_at when that column is absent" do
    connection.create_table RECORDINGS, id: :uuid do |t|
      t.uuid :parent_recording_id
      t.string :recordable_type, null: false
      t.uuid :recordable_id, null: false
      t.timestamps
    end

    AddUniquePublishableChildIndexConcurrently.new.migrate(:up)
    index = connection.indexes(RECORDINGS).find { |candidate| candidate.name == UNIQUE_INDEX }

    assert index.valid?
    assert_includes index.where, "recordable_type"
    refute_includes index.where, "trashed_at"

    sql, = capture_sql { AddUniquePublishableChildIndexConcurrently.new.migrate(:up) }
    refute_includes sql.join("\n"), "CREATE UNIQUE INDEX"
  end

  test "a unique index that is not the old publishable predicate is not replaced" do
    create_recordings_table
    connection.add_index RECORDINGS, :parent_recording_id,
                        unique: true,
                        name: UNIQUE_INDEX,
                        where: "recordable_type = 'Other'"

    error = assert_raises(RuntimeError) do
      AddUniquePublishableChildIndexConcurrently.new.migrate(:up)
    end

    assert_match(/does not match/, error.message)
    assert_match(/FROM "[\w.]+"\."recording_studio_recordings"/, error.message)
    assert_match(/DROP INDEX CONCURRENTLY "[\w.]+"\."#{UNIQUE_INDEX}"/, error.message)
    assert_match(/HAVING count\(\*\) > 1/, error.message)
    assert_match(%r{bin/rails db:migrate}, error.message)
    refute_match(/lock_timeout/i, error.message)
    assert connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
    assert_not connection.index_exists?(RECORDINGS, name: "#{UNIQUE_INDEX}_new")
  end

  test "an older stricter unique index is swapped without a gap" do
    create_recordings_table
    connection.add_index RECORDINGS, :parent_recording_id,
                        unique: true,
                        name: UNIQUE_INDEX,
                        where: "recordable_type = 'RecordingStudioPublishable::Publishable'"

    sql, = capture_sql { AddUniquePublishableChildIndexConcurrently.new.migrate(:up) }
    joined = sql.join("\n")
    create_at = joined.index("CREATE UNIQUE INDEX CONCURRENTLY")
    drop_at = joined.index("DROP INDEX CONCURRENTLY")
    rename_at = joined.index("RENAME TO")

    assert create_at
    assert drop_at
    assert rename_at
    assert_operator create_at, :<, drop_at
    assert_operator drop_at, :<, rename_at
    assert_includes joined, "#{UNIQUE_INDEX}_new"
    assert_includes joined, "SET statement_timeout = '0'"
    assert_not connection.index_exists?(RECORDINGS, name: "#{UNIQUE_INDEX}_new")
    index = connection.indexes(RECORDINGS).find { |candidate| candidate.name == UNIQUE_INDEX }
    assert index.valid?
    assert_includes index.where, "trashed_at"
  end

  test "a valid replacement index is renamed when the old index is already gone" do
    create_recordings_table
    connection.add_index RECORDINGS, :parent_recording_id,
                        unique: true,
                        name: "#{UNIQUE_INDEX}_new",
                        where: "recordable_type = 'RecordingStudioPublishable::Publishable' AND trashed_at IS NULL"

    AddUniquePublishableChildIndexConcurrently.new.migrate(:up)

    assert_not connection.index_exists?(RECORDINGS, name: "#{UNIQUE_INDEX}_new")
    index = connection.indexes(RECORDINGS).find { |candidate| candidate.name == UNIQUE_INDEX }
    assert index.valid?
    assert_includes index.where, "trashed_at"
  end

  test "an invalid replacement index is dropped and the old unique index stays" do
    create_recordings_table
    connection.add_index RECORDINGS, :parent_recording_id,
                        unique: true,
                        name: UNIQUE_INDEX,
                        where: "recordable_type = 'RecordingStudioPublishable::Publishable'"
    pid = connection.select_value("SELECT pg_backend_pid()")
    connection.execute("SET statement_timeout = '20s'")
    blocker = open_pg
    poller = open_pg
    blocker.exec("BEGIN ISOLATION LEVEL REPEATABLE READ")
    blocker.exec("SELECT count(*) FROM recording_studio_recordings")
    watcher_error = nil
    replacement = "#{UNIQUE_INDEX}_new"

    watcher = Thread.new do
      cancel_when_index_is_invalid(poller, blocker, replacement, pid)
    rescue StandardError => error
      watcher_error = error
      rollback_pg(blocker)
    end

    error = assert_raises(RuntimeError) do
      AddUniquePublishableChildIndexConcurrently.new.migrate(:up)
    end
    watcher.join
    flunk(watcher_error.to_s) if watcher_error

    assert_match(/INVALID/, error.message)
    assert_match(/still in place/, error.message)
    assert_match(%r{bin/rails db:migrate}, error.message)
    assert_match(/FROM "[\w.]+"\."recording_studio_recordings"/, error.message)
    assert_not connection.index_exists?(RECORDINGS, name: replacement)
    assert connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
    assert index_valid?(RECORDINGS, UNIQUE_INDEX)
    old = connection.indexes(RECORDINGS).find { |candidate| candidate.name == UNIQUE_INDEX }
    refute_includes old.where, "trashed_at"
  ensure
    watcher&.kill
    [blocker, poller].each { |conn| close_pg(conn) }
  end

  test "a host statement_timeout of 3s does not cancel the concurrent build" do
    create_recordings_table
    connection.execute("SET statement_timeout = '3s'")
    blocker = open_pg
    blocker.exec("BEGIN ISOLATION LEVEL REPEATABLE READ")
    blocker.exec("SELECT count(*) FROM recording_studio_recordings")
    holder = Thread.new do
      sleep 4
      blocker.exec("COMMIT")
    end

    sql, = capture_sql { AddUniquePublishableChildIndexConcurrently.new.migrate(:up) }
    holder.join

    assert index_valid?(RECORDINGS, UNIQUE_INDEX)
    assert_includes sql.join("\n"), "SET statement_timeout = '0'"
    assert_includes sql.join("\n"), "SET lock_timeout = '0'"
    assert_equal "3s", connection.select_value("SHOW statement_timeout")
  ensure
    holder&.kill
    close_pg(blocker)
  end

  test "a build blocked by an open transaction does not leave an invalid index" do
    create_recordings_table
    pid = connection.select_value("SELECT pg_backend_pid()")
    connection.execute("SET statement_timeout = '20s'")
    blocker = open_pg
    poller = open_pg
    blocker.exec("BEGIN ISOLATION LEVEL REPEATABLE READ")
    blocker.exec("SELECT count(*) FROM recording_studio_recordings")
    watcher_error = nil

    watcher = Thread.new do
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
      loop do
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          watcher_error = "timed out waiting for the invalid index"
          blocker.exec("COMMIT")
          break
        end

        seen = poller.exec_params(<<~SQL, [UNIQUE_INDEX])
          SELECT i.indisvalid
          FROM pg_class c
          INNER JOIN pg_index i ON i.indexrelid = c.oid
          WHERE c.relname = $1
        SQL
        unless seen.ntuples.positive? && seen.getvalue(0, 0) == "f"
          sleep 0.05
          next
        end

        poller.exec_params("SELECT pg_cancel_backend($1)", [pid])
        sleep 0.25
        blocker.exec("COMMIT")
        break
      end
    rescue StandardError => error
      watcher_error = error
      rollback_pg(blocker)
    end

    error = assert_raises(RuntimeError) do
      AddUniquePublishableChildIndexConcurrently.new.migrate(:up)
    end
    watcher.join
    flunk(watcher_error.to_s) if watcher_error

    assert_match(/INVALID/, error.message)
    assert_match(/dropped that invalid index/, error.message)
    assert_match(%r{bin/rails db:migrate}, error.message)
    refute_match(/lock_timeout/i, error.message)
    assert_not connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
  ensure
    watcher&.kill
    [blocker, poller].each { |conn| close_pg(conn) }
  end

  private

  def load_gem_migrations
    return if self.class.instance_variable_get(:@gem_migrations_loaded)

    verbose = $VERBOSE
    $VERBOSE = nil
    Dir[GEM_MIGRATIONS.join("[0-9]*_*.rb").to_s].sort.each { |path| load path }
    $VERBOSE = verbose
    self.class.instance_variable_set(:@gem_migrations_loaded, true)
  end

  def connection
    ActiveRecord::Base.connection
  end

  def scratch_config
    hash = @original_config.configuration_hash.deep_dup
    hash[:max_connections] = 1
    hash.delete(:pool)
    hash[:database] = @scratch
    url = hash[:url].presence || ENV["DATABASE_URL"].presence
    if url.present?
      uri = URI.parse(url)
      uri.path = "/#{@scratch}"
      hash[:url] = uri.to_s
    end
    hash
  end

  def restore_original_connection
    return unless @original_config

    ActiveRecord::Base.connection_pool.disconnect!
    ActiveRecord::Base.establish_connection(@original_config)
  end

  def with_original_connection
    restore_original_connection
    yield
  end

  def drop_scratch_database
    return if @scratch.blank?

    admin = ActiveRecord::Base.connection
    exists = admin.select_value(
      "SELECT 1 FROM pg_database WHERE datname = #{admin.quote(@scratch)}"
    )
    admin.drop_database(@scratch) if exists
  end

  def migration_context
    pool = ActiveRecord::Base.connection_pool
    ActiveRecord::MigrationContext.new(
      [GEM_MIGRATIONS.to_s],
      ActiveRecord::SchemaMigration.new(pool),
      ActiveRecord::InternalMetadata.new(pool)
    )
  end

  def migrate_pending_after(versions)
    context = migration_context
    context.schema_migration.create_table
    versions.each { |version| context.schema_migration.create_version(version) }
    context.migrate
  end

  def capture_sql
    statements = []
    open_transactions = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      statements << sql
      next unless sql.include?("CONCURRENTLY")

      open_transactions << ActiveRecord::Base.connection.open_transactions
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    [statements, open_transactions]
  end

  def create_recordings_table
    connection.create_table RECORDINGS, id: :uuid do |t|
      t.uuid :parent_recording_id
      t.string :recordable_type, null: false
      t.uuid :recordable_id, null: false
      t.datetime :trashed_at
      t.timestamps
    end
  end

  def create_publishables_table
    connection.create_table PUBLISHABLES, id: :uuid do |t|
      t.string :status, null: false, default: "draft"
      t.datetime :publish_at
      t.datetime :unpublish_at
      t.timestamps
    end
  end

  def add_unique_child_index
    connection.add_index RECORDINGS, :parent_recording_id,
                        unique: true,
                        name: UNIQUE_INDEX,
                        where: "recordable_type = 'RecordingStudioPublishable::Publishable' AND trashed_at IS NULL"
  end

  def install_already_ran_schema
    create_recordings_table
    run_v090_migration(
      "20250101000001_create_recording_studio_publishable_publishables.rb",
      "CreateRecordingStudioPublishablePublishables",
      "PublishableIndexesV090Create"
    )
    run_v090_migration(
      "20260516000100_add_indexes_to_publishable.rb",
      "AddIndexesToPublishable",
      "PublishableIndexesV090AddIndexes"
    )
  end

  def run_v090_migration(filename, original_class, class_name)
    unless Object.const_defined?(class_name, false)
      source = File.read(Rails.root.join("test/fixtures/publishable_migrations_0_9_0", filename))
      raise "0.9.0 migration #{filename} is missing" unless source.include?("class #{original_class}")

      TOPLEVEL_BINDING.eval(source.sub("class #{original_class}", "class #{class_name}"), filename)
    end
    Object.const_get(class_name).new.migrate(:up)
  end

  def cancel_when_index_is_invalid(poller, blocker, index_name, pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
    loop do
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        blocker.exec("COMMIT")
        raise "timed out waiting for the invalid index #{index_name}"
      end

      seen = poller.exec_params(<<~SQL, [index_name])
        SELECT i.indisvalid
        FROM pg_class c
        INNER JOIN pg_index i ON i.indexrelid = c.oid
        WHERE c.relname = $1
      SQL
      unless seen.ntuples.positive? && seen.getvalue(0, 0) == "f"
        sleep 0.05
        next
      end

      poller.exec_params("SELECT pg_cancel_backend($1)", [pid])
      sleep 0.25
      blocker.exec("COMMIT")
      break
    end
  end

  def rollback_pg(conn)
    return unless conn && !conn.finished?
    return unless [PG::PQTRANS_INTRANS, PG::PQTRANS_INERROR].include?(conn.transaction_status)

    conn.exec("ROLLBACK")
  rescue StandardError
    nil
  end

  def close_pg(conn)
    return unless conn

    rollback_pg(conn)
    conn.close unless conn.finished?
  rescue StandardError
    nil
  end

  def open_pg
    hash = scratch_config
    if hash[:url].present?
      PG.connect(hash[:url])
    else
      PG.connect(
        host: hash[:host],
        port: hash[:port],
        user: hash[:username],
        password: hash[:password],
        dbname: hash[:database]
      )
    end
  end

  def status_index_names
    connection.indexes(PUBLISHABLES).filter_map do |index|
      next unless index.columns.is_a?(Array)

      index.name if index.columns.map(&:to_s) == STATUS_COLUMNS
    end.sort
  end

  def index_valid?(table_name, index_name)
    value = connection.select_value(<<~SQL.squish)
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

  def mark_index_invalid(index_name)
    connection.execute(<<~SQL.squish)
      UPDATE pg_index
      SET indisvalid = false
      WHERE indexrelid = #{connection.quote(index_name)}::regclass
    SQL
  end
end
