# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioPublishable
  module Generators
    # Generator to install RecordingStudioPublishable migrations into the host application.
    #
    # Usage:
    #   rails generate recording_studio_publishable:migrations
    #
    # Options:
    #   --skip-existing  Skip migrations that already exist in the host app
    #
    class MigrationsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("../../../..", __dir__)

      desc "Copy RecordingStudioPublishable migrations to your application"

      class_option :skip_existing, type: :boolean, default: true,
                                   desc: "Skip migrations that already exist (based on name, ignoring timestamp)"

      def copy_migrations
        migrations_dir = File.join(self.class.source_root, "db", "migrate")

        unless File.directory?(migrations_dir)
          say "No migrations found in RecordingStudioPublishable engine.", :yellow
          return
        end

        # Gem filename order is the order Rails should run them in.
        migration_files = Dir.children(migrations_dir).grep(/\.rb\z/).sort.map do |name|
          File.join(migrations_dir, name)
        end

        if migration_files.empty?
          say "No migrations found in RecordingStudioPublishable engine.", :yellow
          return
        end

        say "Found #{migration_files.size} migration(s) to install:", :green

        # Migration versions are one second. Sleeping a fraction of a second
        # still stamps every copy with the same version, and Rails then raises
        # DuplicateMigrationVersionError. Start past now and past any host
        # version, then add 1, 2, 3... so the copies stay unique and in gem order.
        base = [Time.now.utc.strftime("%Y%m%d%H%M%S").to_i, highest_host_migration_version].max
        sequence = 0

        migration_files.each do |source_path|
          filename = File.basename(source_path)
          migration_name = filename.sub(/^\d+_/, "")

          if options[:skip_existing] && migration_exists?(migration_name)
            say "  skip  #{migration_name} (already exists)", :yellow
            next
          end

          sequence += 1
          timestamp = (base + sequence).to_s
          destination_filename = "#{timestamp}_#{migration_name}"
          destination_path = File.join("db/migrate", destination_filename)

          copy_file source_path, destination_path
          say "  create  #{destination_path}", :green
        end

        say "\nRun 'bin/rails db:migrate' to apply the migrations.", :green
        say "Index changes use CONCURRENTLY and are safe on a live recordings table.", :green
        say "Run db:migrate on a direct database connection, not through PgBouncer transaction pooling.", :green
      end

      private

      def migration_exists?(migration_name)
        Dir.glob(File.join(destination_root, "db/migrate", "*_#{migration_name}")).any?
      end

      def highest_host_migration_version
        directory = File.join(destination_root, "db/migrate")
        return 0 unless File.directory?(directory)

        versions = Dir.children(directory).filter_map do |name|
          name[/\A(\d+)_.*\.rb\z/, 1]&.to_i
        end
        versions.max || 0
      end
    end
  end
end
