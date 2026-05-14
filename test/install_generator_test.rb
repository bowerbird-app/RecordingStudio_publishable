# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_publishable/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  INSTALL_TEMPLATE_PATH = File.expand_path(
    "../lib/generators/recording_studio_publishable/install/templates/INSTALL.md",
    __dir__
  )

  def with_temp_app
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/assets/tailwind"))
      yield dir
    end
  end

  def build_generator(destination_root, options = {})
    RecordingStudioPublishable::Generators::InstallGenerator.new(
      [],
      options,
      destination_root: destination_root
    )
  end

  def test_mount_engine_uses_configured_mount_path
    generator = build_generator("/tmp", mount_path: "/addons/recording")
    routes = []

    generator.stub(:route, ->(value) { routes << value }) do
      generator.mount_engine
    end

    assert_equal ["mount RecordingStudioPublishable::Engine, at: \"/addons/recording\""], routes
  end

  def test_install_migrations_invokes_migrations_generator
    generator = build_generator("/tmp")
    commands = []

    generator.stub(:generate, ->(command) { commands << command }) do
      generator.install_migrations
    end

    assert_equal ["recording_studio_publishable:migrations"], commands
  end

  def test_add_seed_template_creates_seed_file_when_missing
    with_temp_app do |dir|
      FileUtils.mkdir_p(File.join(dir, "db"))
      generator = build_generator(dir)

      generator.stub(:say, nil) do
        generator.add_seed_template
      end

      seeds = File.read(File.join(dir, "db/seeds.rb"))
      assert_includes seeds, "# BEGIN RecordingStudioPublishable seeds"
      assert_includes seeds, 'ENV.fetch("RECORDING_STUDIO_PUBLISHABLE_PARENT_ID", nil)'
      assert_includes seeds, "RecordingStudioPublishable::Services::Publishables::Update.call"
    end
  end

  def test_add_seed_template_does_not_duplicate_existing_block
    with_temp_app do |dir|
      FileUtils.mkdir_p(File.join(dir, "db"))
      seeds_path = File.join(dir, "db/seeds.rb")
      File.write(seeds_path, <<~RUBY)
        # BEGIN RecordingStudioPublishable seeds
        # Existing snippet
        # END RecordingStudioPublishable seeds
      RUBY

      generator = build_generator(dir)

      generator.stub(:say, nil) do
        generator.add_seed_template
      end

      seeds = File.read(seeds_path)
      assert_equal 1, seeds.scan("# BEGIN RecordingStudioPublishable seeds").size
    end
  end

  def test_add_tailwind_source_injects_engine_and_flatpack_sources
    with_temp_app do |dir|
      css_path = File.join(dir, "app/assets/tailwind/application.css")
      File.write(css_path, "@import \"tailwindcss\";\n")

      generator = build_generator(dir)

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, nil) do
          generator.add_tailwind_source
        end
      end

      css = File.read(css_path)
      assert_tailwind_sources_present(css)
    end
  end

  def test_add_tailwind_source_does_not_duplicate_existing_entries
    with_temp_app do |dir|
      css_path = File.join(dir, "app/assets/tailwind/application.css")
      File.write(css_path, <<~CSS)
        @import "tailwindcss";
        @source "../../vendor/bundle/**/recording_studio_publishable/app/views/**/*.erb";
        @source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/recording_studio_publishable-*/app/views/**/*.erb";
        @source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";
        @source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";
      CSS

      generator = build_generator(dir)

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, nil) do
          generator.add_tailwind_source
        end
      end

      css = File.read(css_path)
      assert_tailwind_sources_present(css)
      assert_tailwind_sources_count(css, 1)
    end
  end

  def test_add_tailwind_source_reports_missing_tailwind_config
    with_temp_app do |dir|
      FileUtils.rm_rf(File.join(dir, "app/assets/tailwind"))
      generator = build_generator(dir)
      messages = []

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, ->(message, color = nil) { messages << [message, color] }) do
          generator.add_tailwind_source
        end
      end

      assert_includes messages, ["Tailwind CSS not detected. Skipping Tailwind configuration.", :yellow]
      assert_includes messages, ["If you use Tailwind, add these lines to your Tailwind CSS config:", :yellow]
      tailwind_source_lines.each do |line|
        assert_includes messages, ["  #{line}", :yellow]
      end
    end
  end

  def test_add_tailwind_source_reports_manual_configuration_when_import_is_missing
    with_temp_app do |dir|
      css_path = File.join(dir, "app/assets/tailwind/application.css")
      File.write(css_path, "@source \"../local/**/*.erb\";\n")
      generator = build_generator(dir)
      messages = []

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, ->(message, color = nil) { messages << [message, color] }) do
          generator.add_tailwind_source
        end
      end

      assert_equal "@source \"../local/**/*.erb\";\n", File.read(css_path)
      assert_includes messages, ["Could not find @import \"tailwindcss\" in your Tailwind config.", :yellow]
      assert_includes messages, ["Please manually add these lines to your Tailwind CSS config:", :yellow]
      tailwind_source_lines.each do |line|
        assert_includes messages, ["  #{line}", :yellow]
      end
    end
  end

  def test_show_readme_displays_install_guide_for_invoke_behavior
    generator = build_generator("/tmp")
    shown_templates = []

    generator.stub(:behavior, :invoke) do
      generator.stub(:readme, ->(template) { shown_templates << template }) do
        generator.show_readme
      end
    end

    assert_equal ["INSTALL.md"], shown_templates
  end

  def test_install_guide_includes_migration_and_host_setup_steps
    install_guide = File.read(INSTALL_TEMPLATE_PATH)

    assert_includes install_guide, "bin/rails db:migrate"
    assert_includes install_guide, "db/seeds.rb"
    assert_includes install_guide, "RECORDING_STUDIO_PUBLISHABLE_PARENT_ID"
    assert_includes install_guide, "wire the current actor plus parent-recording authorization"
    assert_includes install_guide, "default public route"
  end

  private

  def assert_tailwind_sources_present(css)
    tailwind_source_lines.each do |line|
      assert_includes css, line
    end
  end

  def assert_tailwind_sources_count(css, count)
    tailwind_source_lines.each do |line|
      assert_equal count, css.scan(line).size
    end
  end

  def tailwind_source_lines
    [
      '@source "../../vendor/bundle/**/recording_studio_publishable/app/views/**/*.erb";',
      '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/' \
      'recording_studio_publishable-*/app/views/**/*.erb";',
      '@source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";',
      '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";'
    ]
  end
end
