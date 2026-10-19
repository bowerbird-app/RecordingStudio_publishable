# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_publishable/migrations/migrations_generator"

class PublishableMigrationCopiesTest < Minitest::Test
  GEM_MIGRATIONS = File.expand_path("../db/migrate", __dir__)
  DUMMY_MIGRATIONS = File.expand_path("dummy/db/migrate", __dir__)

  def test_dummy_migration_copies_match_gem_files_byte_for_byte
    gem_files = Dir.children(GEM_MIGRATIONS).grep(/\.rb\z/).sort
    assert_predicate gem_files, :any?

    gem_files.each do |filename|
      suffix = filename.sub(/^\d+_/, "")
      copies = Dir.children(DUMMY_MIGRATIONS).select { |candidate| candidate.sub(/^\d+_/, "") == suffix }
      assert_equal 1, copies.size, "expected one dummy copy of #{suffix}"
      gem_bytes = File.binread(File.join(GEM_MIGRATIONS, filename))
      dummy_bytes = File.binread(File.join(DUMMY_MIGRATIONS, copies.first))
      assert_equal gem_bytes, dummy_bytes, "#{copies.first} differs from #{filename}"
    end
  end

  def test_migrations_generator_copies_gem_files_byte_for_byte
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      generator = RecordingStudioPublishable::Generators::MigrationsGenerator.new(
        [],
        {},
        destination_root: dir
      )

      generator.stub(:say, nil) do
        generator.copy_migrations
      end

      copied = Dir.children(File.join(dir, "db/migrate")).grep(/\.rb\z/)
      gem_files = Dir.children(GEM_MIGRATIONS).grep(/\.rb\z/)
      assert_equal gem_files.size, copied.size

      gem_files.each do |filename|
        suffix = filename.sub(/^\d+_/, "")
        copy = copied.find { |candidate| candidate.sub(/^\d+_/, "") == suffix }
        assert copy, "generator did not copy #{suffix}"
        assert_equal File.binread(File.join(GEM_MIGRATIONS, filename)),
                     File.binread(File.join(dir, "db/migrate", copy))
      end
    end
  end

  def test_create_migration_does_not_index_the_shared_recordings_table
    source = File.read(File.join(GEM_MIGRATIONS, "20250101000001_create_recording_studio_publishable_publishables.rb"))

    refute_match(/add_index\s+:recording_studio_recordings/, source)
    assert_includes source, "index_rs_publishables_on_state_window"
  end

  def test_concurrent_migrations_declare_the_production_guards
    unique = File.read(File.join(GEM_MIGRATIONS, "20261019120000_add_unique_publishable_child_index_concurrently.rb"))
    duplicate = File.read(File.join(GEM_MIGRATIONS, "20261019120001_drop_duplicate_publishable_status_index.rb"))
    indexes = File.read(File.join(GEM_MIGRATIONS, "20260516000100_add_indexes_to_publishable.rb"))

    assert_includes unique, "disable_ddl_transaction!"
    assert_includes unique, "algorithm: :concurrently"
    assert_includes unique, "if_not_exists: true"
    assert_includes unique, "unique_child_index_shape?"
    assert_includes unique, "drop_invalid_unique_child_index"
    assert_includes unique, "with_concurrent_lock_timeout"
    assert_includes unique, "PublishableChildIndex::V1"
    assert_includes unique, "swap_stricter_unique_child_index!"
    refute_includes unique, "5s"

    assert_includes duplicate, "disable_ddl_transaction!"
    assert_includes duplicate, "algorithm: :concurrently"
    assert_includes duplicate, "if_exists: true"
    assert_includes duplicate, "with_concurrent_lock_timeout"
    assert_includes duplicate, "PublishableChildIndex::V1"
    assert_includes duplicate, "plain_status_index?"
    assert_includes duplicate, "index_rs_publishables_on_state_window"
    assert_includes duplicate, "index_publishables_on_status_and_publish_times"
    assert_includes duplicate, "IrreversibleMigration"
    assert_includes duplicate, "refuse_invalid_unique_child_index!"
    refute_includes duplicate, "AND trashed_at IS NULL"
    refute_includes duplicate, "5s"
    refute_match(/remove_index[^\n]+index_rs_publishables_on_state_window/, duplicate)

    assert_includes indexes, "equivalent_status_index?"
    assert_includes indexes, "Array(index.columns) == STATUS_COLUMNS"
    assert_includes indexes, "index.opclasses.blank?"
    assert_includes indexes, "index.orders.blank?"
    assert_includes indexes, "index.include.blank?"
    assert_includes indexes, "if_not_exists: true"

    shared = File.read(File.expand_path("../lib/recording_studio_publishable/publishable_child_index.rb", __dir__))
    assert_includes shared, "connection.indexes(table_name).find { |candidate| candidate.name == index_name }&.valid?"
    assert_includes shared, "def unique_child_index_where_clause"
    assert_includes shared, "CONCURRENT_LOCK_TIMEOUT = \"0\""
    assert_includes shared, "SHOW statement_timeout"
    assert_includes shared, "module V1"
    assert_includes shared, "schema_qualified_table_name"
    assert_includes shared, "bin/rails db:migrate"
    refute_includes shared, "5s"
    refute_includes shared, "current_schema()"
  end

  def test_migrations_generator_versions_are_unique_increasing_and_above_existing
    Dir.mktmpdir do |dir|
      migrate_dir = File.join(dir, "db/migrate")
      FileUtils.mkdir_p(migrate_dir)
      existing_version = 20_990_101_000_000
      File.write(File.join(migrate_dir, "#{existing_version}_already.rb"), "# existing\n")
      File.write(File.join(migrate_dir, "20000101000000_old.rb"), "# old\n")

      generator = RecordingStudioPublishable::Generators::MigrationsGenerator.new(
        [],
        {},
        destination_root: dir
      )
      generator.stub(:say, nil) { generator.copy_migrations }

      gem_order = Dir.children(GEM_MIGRATIONS).grep(/\.rb\z/).sort.map { |name| name.sub(/^\d+_/, "") }
      copied = Dir.children(migrate_dir).grep(/\.rb\z/)
      assert_copied_versions(copied, gem_order, existing_version)
    end
  end

  def assert_copied_versions(copied, gem_order, existing_version)
    ordered = copied.select { |name| gem_order.include?(migration_suffix(name)) }
    ordered = ordered.sort_by { |name| migration_version(name) }
    versions = ordered.map { |name| migration_version(name) }

    assert_equal(gem_order, ordered.map { |name| migration_suffix(name) })
    assert_version_sequence(versions, existing_version)
    assert_equal(copied.map { |name| migration_version(name) }.uniq.size, copied.size)
  end

  def assert_version_sequence(versions, existing_version)
    expected = (1..versions.length).map { |offset| existing_version + offset }

    assert_equal versions, versions.uniq
    assert_equal versions.sort, versions
    assert_equal expected, versions
    assert(versions.all? { |version| version > existing_version })
  end

  def migration_version(name)
    name[/\A(\d+)/, 1].to_i
  end

  def migration_suffix(name)
    name.sub(/^\d+_/, "")
  end

  def test_generator_rerun_copies_nothing
    Dir.mktmpdir do |dir|
      migrate_dir = File.join(dir, "db/migrate")
      FileUtils.mkdir_p(migrate_dir)
      generator = RecordingStudioPublishable::Generators::MigrationsGenerator.new([], {}, destination_root: dir)

      generator.stub(:say, nil) { generator.copy_migrations }
      first = Dir.children(migrate_dir).sort
      generator.stub(:say, nil) { generator.copy_migrations }

      assert_equal first, Dir.children(migrate_dir).sort
      assert_equal Dir.children(GEM_MIGRATIONS).grep(/\.rb\z/).size, first.size
    end
  end

  def test_generator_uses_now_when_it_is_later_than_the_host_max
    Dir.mktmpdir do |dir|
      migrate_dir = File.join(dir, "db/migrate")
      FileUtils.mkdir_p(migrate_dir)
      File.write(File.join(migrate_dir, "20000101000000_old.rb"), "# old\n")
      before = Time.now.utc
      generator = RecordingStudioPublishable::Generators::MigrationsGenerator.new([], {}, destination_root: dir)
      generator.stub(:say, nil) { generator.copy_migrations }

      versions = Dir.children(migrate_dir).filter_map do |name|
        migration_version(name) if migration_version(name) > 20_000_101_000_000
      end.sort
      assert_predicate versions, :any?
      assert_equal versions.uniq, versions
      assert(versions.all? { |version| version > before.strftime("%Y%m%d%H%M%S").to_i })
      versions.each { |version| assert_valid_migration_clock(version) }
      assert_consecutive_seconds(versions)
    end
  end

  def test_generator_skips_install_task_copies
    Dir.mktmpdir do |dir|
      migrate_dir = File.join(dir, "db/migrate")
      FileUtils.mkdir_p(migrate_dir)
      installed = "20200101000000_create_recording_studio_publishable_publishables.recording_studio_publishable.rb"
      File.write(File.join(migrate_dir, installed), "# installed\n")
      generator = RecordingStudioPublishable::Generators::MigrationsGenerator.new([], {}, destination_root: dir)
      generator.stub(:say, nil) { generator.copy_migrations }

      names = Dir.children(migrate_dir)
      assert_includes names, installed
      refute(names.any? { |name| name.match?(/\A\d+_create_recording_studio_publishable_publishables\.rb\z/) })
      assert(names.any? { |name| name.end_with?("_add_indexes_to_publishable.rb") })
    end
  end

  def assert_valid_migration_clock(version)
    text = format("%014d", version)
    assert_operator text[10, 2].to_i, :<=, 59
    assert_operator text[12, 2].to_i, :<=, 59
  end

  def assert_consecutive_seconds(versions)
    times = versions.map { |version| Time.utc(*migration_clock_parts(version)) }
    times.each_cons(2) { |earlier, later| assert_equal 1, later - earlier }
  end

  def migration_clock_parts(version)
    text = format("%014d", version)
    [text[0, 4], text[4, 2], text[6, 2], text[8, 2], text[10, 2], text[12, 2]].map(&:to_i)
  end

  def test_gemspec_ships_upgrading_notes
    spec = Gem::Specification.load(File.expand_path("../recording_studio_publishable.gemspec", __dir__))

    assert_includes spec.files, "UPGRADING.md"
  end
end
