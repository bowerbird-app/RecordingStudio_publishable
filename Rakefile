# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require "bundler/gem_tasks"
require "rake/testtask"

DUMMY_TEST_FILES = %w[
  test/controllers/docs_controller_test.rb
  test/controllers/home_controller_test.rb
  test/controllers/published_controller_test.rb
  test/models/recording_studio_publishable/publishable_test.rb
  test/services/recording_studio_publishable/publications/ensure_child_test.rb
  test/services/recording_studio_publishable/publications/update_test.rb
  test/services/recording_studio_publishable/publications/resolve_test.rb
].map { |path| File.expand_path(path, __dir__) }.freeze
DUMMY_GEMFILE = File.expand_path("test/dummy/Gemfile", __dir__)
DUMMY_APP_ROOT = File.expand_path("test/dummy", __dir__)
ROOT_TEST_EXCLUSIONS = %w[
  test/controllers/docs_controller_test.rb
  test/controllers/home_controller_test.rb
  test/controllers/published_controller_test.rb
  test/models/recording_studio_publishable/publishable_test.rb
  test/services/recording_studio_publishable/publications/ensure_child_test.rb
  test/services/recording_studio_publishable/publications/update_test.rb
  test/services/recording_studio_publishable/publications/resolve_test.rb
  test/rename_verification_test.rb
  test/dummy/**/*_test.rb
].freeze

def run_command!(env, *command)
  return if system(env, *command)

  raise "Command failed (#{Process.last_status.exitstatus}): #{command.join(' ')}"
end

def dummy_bundle_env
  {
    "BUNDLE_GEMFILE" => DUMMY_GEMFILE,
    "DISABLE_SIMPLECOV" => "true",
    "RAILS_ENV" => ENV.fetch("RAILS_ENV", "test")
  }.merge(dummy_database_env)
end

def dummy_database_env
  {
    "DATABASE_URL" => ENV.fetch("DATABASE_URL", nil),
    "DB_HOST" => ENV.fetch("DB_HOST", nil),
    "DB_NAME" => ENV.fetch("DB_NAME", nil),
    "DB_PASSWORD" => ENV.fetch("DB_PASSWORD", "postgres"),
    "DB_PORT" => ENV.fetch("DB_PORT", nil),
    "DB_TEST_NAME" => ENV.fetch("DB_TEST_NAME", nil),
    "DB_USER" => ENV.fetch("DB_USER", "postgres")
  }.compact
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"].exclude(*ROOT_TEST_EXCLUSIONS)
  t.verbose = false
end

namespace :test do
  desc "Run rename verification tests to validate gem naming consistency"
  task :rename_verification do
    ruby "test/rename_verification_test.rb", verbose: true
  end

  desc "Run rename verification tests in verbose mode"
  task :rename_verification_verbose do
    ruby "test/rename_verification_test.rb", "--verbose", verbose: true
  end

  desc "Run dummy app integration tests under the dummy app bundle"
  task :dummy do
    Dir.chdir(DUMMY_APP_ROOT) do
      Bundler.with_unbundled_env do
        env = dummy_bundle_env

        run_command!(env, "bin/rails", "db:prepare")
        run_command!(env, "bundle", "exec", "bin/rails", "test")
        run_command!(env, "bundle", "exec", "ruby", "-I#{File.expand_path('test', __dir__)}", *DUMMY_TEST_FILES)
      end
    end
  end

  desc "Run gem and dummy app tests"
  task all: %i[test dummy]
end

namespace :app do
  desc "Run all tests for the gem"
  task test: "test:all"
end

task default: :test
