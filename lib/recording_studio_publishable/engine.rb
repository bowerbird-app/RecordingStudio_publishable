# frozen_string_literal: true

require_relative "../../app/helpers/recording_studio_publishable/copy_helper"
require_relative "../../app/helpers/recording_studio_publishable/share_helper"
require_relative "../../app/helpers/recording_studio_publishable/http_cache_helper"

module RecordingStudioPublishable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioPublishable
    paths.add "app/components", eager_load: true

    initializer "recording_studio_publishable.view_helpers" do
      ActiveSupport.on_load(:action_view) do
        include RecordingStudioPublishable::CopyHelper
        include RecordingStudioPublishable::ShareHelper
        include RecordingStudioPublishable::HttpCacheHelper
      end
    end

    initializer "recording_studio_publishable.http_cache" do |app|
      app.middleware.insert_before(
        ActionDispatch::Cookies,
        RecordingStudioPublishable::HttpCache::Commit
      )
    end

    initializer "recording_studio_publishable.public_root_resolution" do
      engine = self

      config.to_prepare do
        engine.send(:skip_public_root_resolution!)
      end
    end

    initializer "recording_studio_publishable.assets" do |app|
      next unless app.config.respond_to?(:assets)
      next unless app.config.assets.respond_to?(:paths)

      assets_path = root.join("app/javascript")
      app.config.assets.paths << assets_path unless app.config.assets.paths.include?(assets_path)
    end

    initializer "recording_studio_publishable.importmap", before: "importmap" do |app|
      next unless app.config.respond_to?(:importmap)
      next unless app.config.importmap.respond_to?(:paths)

      importmap_path = root.join("config/importmap.rb")
      app.config.importmap.paths << importmap_path unless app.config.importmap.paths.include?(importmap_path)
    end

    initializer "recording_studio_publishable.turbo_stream_mime" do
      Mime::Type.register "text/vnd.turbo-stream.html", :turbo_stream unless Mime[:turbo_stream]
    end

    initializer "recording_studio_publishable.load_config" do |app|
      if app.respond_to?(:config_for)
        yaml = begin
          app.config_for(:recording_studio_publishable)
        rescue StandardError
          nil
        end
        RecordingStudioPublishable.configuration.merge!(yaml) if yaml.respond_to?(:each)
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_publishable)
        xcfg = app.config.x.recording_studio_publishable
        RecordingStudioPublishable.configuration.merge!(xcfg.to_h) if xcfg.respond_to?(:to_h)
      end
    rescue StandardError
      nil
    end

    initializer "recording_studio_publishable.register_recording_studio_api_action",
                before: "recording_studio_api.after_initialize" do
      RecordingStudioPublishable::Api.register_capability_action!
    end

    initializer "recording_studio_publishable.extensions" do
      engine = self

      config.to_prepare do
        RecordingStudioPublishable.install_recording_capabilities!
        engine.send(:register_publishable_recordable_type)
      end
    end

    private

    def skip_public_root_resolution!
      controller = RecordingStudioPublishable::PublishedController
      return unless controller.respond_to?(:skip_recording_studio_root_resolution)
      return if controller.instance_variable_defined?(:@publishable_public_root_skipped)

      controller.skip_recording_studio_root_resolution(raise: false, if: :publishable_public_cache_response?)
      controller.instance_variable_set(:@publishable_public_root_skipped, true)
    end

    def register_publishable_recordable_type
      return unless publishable_parent_types_registered?

      RecordingStudio::Capabilities::Publishable.ensure_child_recordable_registered!
    end

    def publishable_parent_types_registered?
      return false unless defined?(RecordingStudio) && RecordingStudio.respond_to?(:configuration)
      return false unless RecordingStudio.configuration.respond_to?(:enabled_recordable_types_for)

      RecordingStudio.configuration.enabled_recordable_types_for(:publishable).any?
    end
  end
end
