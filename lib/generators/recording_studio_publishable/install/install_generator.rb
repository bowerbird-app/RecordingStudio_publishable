# frozen_string_literal: true

require "rails/generators"

module RecordingStudioPublishable
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioPublishable engine into your application"

      class_option(
        :mount_path,
        type: :string,
        default: "/",
        desc: "Route prefix used when mounting the engine (use '/' for the default public route)"
      )

      def install_migrations
        generate "recording_studio_publishable:migrations"
      end

      def mount_engine
        route %(mount RecordingStudioPublishable::Engine, at: "#{options[:mount_path]}")
      end

      def copy_initializer
        template "recording_studio_publishable_initializer.rb", "config/initializers/recording_studio_publishable.rb"
      end

      def add_seed_template
        seed_path = "db/seeds.rb"
        full_seed_path = destination_path(seed_path)

        if File.exist?(full_seed_path) && File.read(full_seed_path).include?(seed_snippet_marker)
          say "RecordingStudioPublishable seed template already present in db/seeds.rb.", :green
          return
        end

        create_file(seed_path, "") unless File.exist?(full_seed_path)

        append_to_file seed_path do
          prefix = File.zero?(full_seed_path) ? "" : "\n"
          "#{prefix}#{seed_template_content}"
        end

        say "Added RecordingStudioPublishable seed template to db/seeds.rb.", :green
      end

      def add_yaml_config
        return unless yes?("Would you like to add `config/recording_studio_publishable.yml` for environment-specific settings? [y/N]")

        template "recording_studio_publishable.yml", "config/recording_studio_publishable.yml"
      end

      def add_tailwind_source
        tailwind_css_path = Rails.root.join("app/assets/tailwind/application.css")
        return show_missing_tailwind_notice unless File.exist?(tailwind_css_path)

        tailwind_content = File.read(tailwind_css_path)
        missing_lines = missing_tailwind_source_lines(tailwind_content)

        if missing_lines.empty?
          say "Tailwind already configured to include RecordingStudioPublishable and FlatPack sources.", :green
          return
        end

        if tailwind_content.include?('@import "tailwindcss"')
          inject_tailwind_sources(tailwind_css_path, missing_lines)
          return
        end

        show_manual_tailwind_notice(missing_lines)
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end

      private

      def show_missing_tailwind_notice
        say "Tailwind CSS not detected. Skipping Tailwind configuration.", :yellow
        say "If you use Tailwind, add these lines to your Tailwind CSS config:", :yellow
        tailwind_source_lines.each do |line|
          say "  #{line}", :yellow
        end
      end

      def missing_tailwind_source_lines(tailwind_content)
        tailwind_source_lines.reject { |line| tailwind_content.include?(line) }
      end

      def inject_tailwind_sources(tailwind_css_path, missing_lines)
        inject_into_file tailwind_css_path, after: "@import \"tailwindcss\";\n" do
          "#{formatted_tailwind_source_block(missing_lines)}\n"
        end
        say "Added RecordingStudioPublishable and FlatPack sources to Tailwind CSS configuration.", :green
        say "Run 'bin/rails tailwindcss:build' to rebuild your CSS.", :green
      end

      def formatted_tailwind_source_block(missing_lines)
        [
          "\n/* Include RecordingStudioPublishable engine views for Tailwind CSS */",
          missing_lines.first(2),
          "\n/* Include FlatPack component sources for Tailwind CSS */",
          missing_lines.drop(2)
        ].flatten.reject(&:empty?).join("\n")
      end

      def show_manual_tailwind_notice(missing_lines)
        say "Could not find @import \"tailwindcss\" in your Tailwind config.", :yellow
        say "Please manually add these lines to your Tailwind CSS config:", :yellow
        missing_lines.each do |line|
          say "  #{line}", :yellow
        end
      end

      def tailwind_source_lines
        [
          '@source "../../vendor/bundle/**/recording_studio_publishable/app/views/**/*.erb";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/recording_studio_publishable-*/app/views/**/*.erb";',
          '@source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";'
        ]
      end

      def destination_path(relative_path)
        File.join(destination_root, relative_path)
      end

      def seed_template_content
        File.read(find_in_source_paths("recording_studio_publishable_seeds.rb"))
      end

      def seed_snippet_marker
        "# BEGIN RecordingStudioPublishable seeds"
      end
    end
  end
end
