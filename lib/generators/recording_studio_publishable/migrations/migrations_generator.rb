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

        # A 14-digit clock time gets real seconds, so second 59 rolls forward.
        # Anything else (001, 8 digits, minute 60, 15 digits) stays an integer:
        # max(now, highest + 1), then + 1 for each following file.
        mode, base = migration_version_base
        sequence = 0

        migration_files.each do |source_path|
          filename = File.basename(source_path)
          migration_name = filename.sub(/^\d+_/, "")

          if options[:skip_existing] && migration_exists?(migration_name)
            say "  skip  #{migration_name} (already exists)", :yellow
            next
          end

          sequence += 1
          timestamp = migration_timestamp(mode, base, sequence)
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
        directory = File.join(destination_root, "db/migrate")
        return false unless File.directory?(directory)

        stem = migration_name.sub(/\.rb\z/, "")
        Dir.children(directory).any? do |name|
          name.match?(/\A\d+_#{Regexp.escape(stem)}(\.recording_studio_publishable)?\.rb\z/)
        end
      end

      def migration_timestamp(mode, base, sequence)
        if mode == :time
          (base + sequence).strftime("%Y%m%d%H%M%S")
        else
          (base + sequence - 1).to_s
        end
      end

      def migration_version_base
        now = Time.now.utc
        highest = highest_host_migration_version
        return [:time, now] if highest.zero?

        parsed = time_from_migration_version(highest)
        return [:time, [now, parsed].max] if parsed

        now_int = now.strftime("%Y%m%d%H%M%S").to_i
        [:integer, [now_int, highest + 1].max]
      end

      def time_from_migration_version(version)
        text = version.to_s
        return nil unless text.match?(/\A\d{14}\z/)

        Time.utc(*migration_clock_parts(text))
      rescue ArgumentError
        nil
      end

      def migration_clock_parts(text)
        [text[0, 4], text[4, 2], text[6, 2], text[8, 2], text[10, 2], text[12, 2]].map(&:to_i)
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
