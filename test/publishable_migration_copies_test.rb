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
    assert_includes unique, "pg_index.indisvalid"
    assert_includes unique, "will not drop a unique index"
    assert_includes unique, "SHOW lock_timeout"

    assert_includes duplicate, "disable_ddl_transaction!"
    assert_includes duplicate, "algorithm: :concurrently"
    assert_includes duplicate, "if_exists: true"
    assert_includes duplicate, "pg_index.indisvalid"
    assert_includes duplicate, "index_rs_publishables_on_state_window"
    assert_includes duplicate, "index_publishables_on_status_and_publish_times"
    assert_includes duplicate, "IrreversibleMigration"
    refute_match(/remove_index[^\n]+index_rs_publishables_on_state_window/, duplicate)

    assert_includes indexes, "equivalent_status_index?"
    assert_includes indexes, "if_not_exists: true"
  end
end
