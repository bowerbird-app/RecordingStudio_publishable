# frozen_string_literal: true

require "test_helper"

class PublishableIndexMigrationsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  GEM_MIGRATIONS = Rails.root.join("../..", "db/migrate").expand_path
  ORIGINAL_INDEX = "index_rs_publishables_on_state_window"
  DUPLICATE_INDEX = "index_publishables_on_status_and_publish_times"
  UNIQUE_INDEX = "index_rs_publishable_child_per_parent"
  SINGLE_CHILD_INDEX = "index_recording_studio_recordings_on_single_child"
  PUBLISHABLES = :recording_studio_publishable_publishables
  RECORDINGS = :recording_studio_recordings
  PUBLISHABLE_TYPE = "RecordingStudioPublishable::Publishable"
  STATUS_COLUMNS = %w[status publish_at unpublish_at].freeze
  ALREADY_RAN = %w[20250101000001 20260515000100 20260516000100].freeze
  DROP_STATUS_SQL = 'DROP INDEX CONCURRENTLY "index_publishables_on_status_and_publish_times"'
  DROP_CHILD_SQL = 'DROP INDEX CONCURRENTLY "index_rs_publishable_child_per_parent"'

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

  test "dummy schema keeps only the core single-child index" do
    schema = File.read(Rails.root.join("db/schema.rb"))
    source = File.read(single_child_migration_path)

    assert_includes schema, SINGLE_CHILD_INDEX
    refute_includes schema, UNIQUE_INDEX
    assert_equal 1, schema.scan(SINGLE_CHILD_INDEX).size
    assert_includes source, PUBLISHABLE_TYPE
    assert_includes source, SINGLE_CHILD_INDEX
    assert_includes source, "if_not_exists: true"
    refute_includes source, UNIQUE_INDEX
    refute_includes source, "trashed_at"
  end

  test "fresh install does not create the old publishable child index" do
    create_recordings_table
    connection.execute("SET lock_timeout = '4s'")
    previous_timeout = connection.select_value("SHOW lock_timeout")

    sql, = capture_sql { migration_context.migrate }
    joined = sql.join("\n")

    assert_equal [ORIGINAL_INDEX], status_index_names
    assert_not connection.index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)
    assert_not connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
    refute_includes joined, UNIQUE_INDEX
    refute_includes joined, "CREATE UNIQUE INDEX"
    refute_includes joined, "DROP INDEX"
    refute_includes joined, "SET lock_timeout = '0'"
    assert_equal previous_timeout, connection.select_value("SHOW lock_timeout")

    second, = capture_sql { migration_context.migrate }
    refute_includes second.join("\n"), "DROP INDEX"
    refute_includes second.join("\n"), "SET lock_timeout"
  end

  test "already-ran hosts drop the old child index and the duplicate status index" do
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
    assert_not connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
    assert_includes joined, DROP_STATUS_SQL
    assert_includes joined, DROP_CHILD_SQL
    assert_includes joined, "SET lock_timeout = '0'"
    assert_includes joined, "SET statement_timeout = '0'"
    refute_includes joined, "5s"
    refute_includes joined, "DROP INDEX CONCURRENTLY \"#{ORIGINAL_INDEX}\""
    assert_equal [0], open_transactions.uniq

    error = assert_raises(ActiveRecord::IrreversibleMigration) do
      DropDuplicatePublishableStatusIndex.new.migrate(:down)
    end
    assert_match(/CONCURRENTLY/, error.message)
    assert_match(/#{ORIGINAL_INDEX}/, error.message)
    assert_equal [ORIGINAL_INDEX], status_index_names

    child_error = assert_raises(ActiveRecord::IrreversibleMigration) do
      DropPublishableChildPerParentIndex.new.migrate(:down)
    end
    assert_match(/single_child_index/, child_error.message)
    assert_not connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
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

  test "duplicate stays when the original index is missing or invalid" do
    create_publishables_table
    connection.add_index PUBLISHABLES, STATUS_COLUMNS, name: DUPLICATE_INDEX

    DropDuplicatePublishableStatusIndex.new.migrate(:up)
    assert connection.index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)
    assert_not connection.index_exists?(PUBLISHABLES, name: ORIGINAL_INDEX)

    connection.add_index PUBLISHABLES, STATUS_COLUMNS, name: ORIGINAL_INDEX
    mark_index_invalid(ORIGINAL_INDEX)
    DropDuplicatePublishableStatusIndex.new.migrate(:up)
    assert connection.index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)
    assert connection.index_exists?(PUBLISHABLES, name: ORIGINAL_INDEX)
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

  test "drop removes a valid old child index and leaves the core index" do
    create_recordings_table
    connection.execute("SET lock_timeout = '4s'")
    previous_timeout = connection.select_value("SHOW lock_timeout")
    add_old_child_index
    add_core_child_index

    sql, open_transactions = capture_sql { DropPublishableChildPerParentIndex.new.migrate(:up) }
    joined = sql.join("\n")

    assert_not connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
    assert index_valid?(RECORDINGS, SINGLE_CHILD_INDEX)
    assert_includes joined, DROP_CHILD_SQL
    assert_includes joined, "SET lock_timeout = '0'"
    assert_includes joined, "SET statement_timeout = '0'"
    refute_includes joined, SINGLE_CHILD_INDEX
    refute_includes joined, "5s"
    assert_equal [0], open_transactions.uniq
    assert_equal previous_timeout, connection.select_value("SHOW lock_timeout")

    second, = capture_sql { DropPublishableChildPerParentIndex.new.migrate(:up) }
    refute_includes second.join("\n"), "DROP INDEX"
    refute_includes second.join("\n"), "SET lock_timeout"
    assert index_valid?(RECORDINGS, SINGLE_CHILD_INDEX)
  end

  test "drop removes an invalid old child index" do
    create_recordings_table
    add_old_child_index
    mark_index_invalid(UNIQUE_INDEX)

    DropPublishableChildPerParentIndex.new.migrate(:up)

    assert_not connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
  end

  test "drop does nothing when the old child index is already gone" do
    create_recordings_table

    sql, = capture_sql { DropPublishableChildPerParentIndex.new.migrate(:up) }

    refute_includes sql.join("\n"), "DROP INDEX"
    refute_includes sql.join("\n"), "SET lock_timeout"
    assert_not connection.index_exists?(RECORDINGS, name: UNIQUE_INDEX)
  end

  test "core index rejects a second publishable child including a trashed one" do
    create_recordings_table
    add_old_child_index
    DropPublishableChildPerParentIndex.new.migrate(:up)
    load_single_child_migration
    AddRecordingStudioSingleChildIndex.new.migrate(:up)

    names = connection.indexes(RECORDINGS).map(&:name)
    assert_includes names, SINGLE_CHILD_INDEX
    assert_not_includes names, UNIQUE_INDEX
    assert_equal 1, names.count { |name| name == SINGLE_CHILD_INDEX }

    parent_id = SecureRandom.uuid
    insert_publishable_child(parent_id)
    assert_raises(ActiveRecord::RecordNotUnique) { insert_publishable_child(parent_id) }

    other_parent = SecureRandom.uuid
    insert_publishable_child(other_parent, trashed_at: Time.current)
    assert_raises(ActiveRecord::RecordNotUnique) { insert_publishable_child(other_parent) }
    insert_recording(other_parent, "Page")
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

  def load_single_child_migration
    return if self.class.instance_variable_get(:@single_child_loaded)

    load single_child_migration_path
    self.class.instance_variable_set(:@single_child_loaded, true)
  end

  def single_child_migration_path
    Rails.root.glob("db/migrate/*_add_recording_studio_single_child_index.rb").sole.to_s
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

  def add_old_child_index
    connection.add_index RECORDINGS, :parent_recording_id,
                        unique: true,
                        name: UNIQUE_INDEX,
                        where: "recordable_type = '#{PUBLISHABLE_TYPE}' AND trashed_at IS NULL"
  end

  def add_core_child_index
    connection.add_index RECORDINGS, %i[parent_recording_id recordable_type],
                        unique: true,
                        name: SINGLE_CHILD_INDEX,
                        where: "recordable_type IN ('#{PUBLISHABLE_TYPE}')"
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

  def insert_publishable_child(parent_id, trashed_at: nil)
    insert_recording(parent_id, PUBLISHABLE_TYPE, trashed_at: trashed_at)
  end

  def insert_recording(parent_id, recordable_type, trashed_at: nil)
    connection.insert(<<~SQL.squish)
      INSERT INTO #{connection.quote_table_name(RECORDINGS)}
        (id, parent_recording_id, recordable_type, recordable_id, trashed_at, created_at, updated_at)
      VALUES (
        #{connection.quote(SecureRandom.uuid)},
        #{connection.quote(parent_id)},
        #{connection.quote(recordable_type)},
        #{connection.quote(SecureRandom.uuid)},
        #{trashed_at ? connection.quote(trashed_at) : "NULL"},
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
    SQL
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
