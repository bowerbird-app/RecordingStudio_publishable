# frozen_string_literal: true

namespace :flat_pack do
  desc "Mirror FlatPack and Recording Studio sources into tmp for Tailwind scanning"
  task :sync_tailwind_sources do
    require "fileutils"

    sync_gem_path("flat_pack", "app/components", "tmp/tailwind/flat_pack_components")
    sync_gem_path("recording_studio", "app/views", "tmp/tailwind/recording_studio_views")
    sync_gem_path("recording_studio_root_switchable", "app/views", "tmp/tailwind/recording_studio_root_switchable_views")
    sync_gem_path("recording_studio_attachable", "app/views", "tmp/tailwind/recording_studio_attachable_views")
  end
end

def sync_gem_path(gem_name, relative_source, relative_target)
  spec = Gem::Specification.find_by_name(gem_name)
  source_path = Pathname.new(spec.gem_dir).join(relative_source)
  return unless source_path.exist?

  target_path = Rails.root.join(relative_target)

  FileUtils.rm_rf(target_path)
  FileUtils.mkdir_p(target_path.dirname)
  FileUtils.cp_r(source_path, target_path)
rescue Gem::MissingSpecError
  nil
end

%w[tailwindcss:build tailwindcss:watch].each do |task_name|
  Rake::Task[task_name].enhance(["flat_pack:sync_tailwind_sources"]) if Rake::Task.task_defined?(task_name)
end
