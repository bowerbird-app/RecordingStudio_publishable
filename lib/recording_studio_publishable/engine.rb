# frozen_string_literal: true

module RecordingStudioPublishable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioPublishable
    paths.add "app/components", eager_load: true

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

    initializer "recording_studio_publishable.before_initialize",
                before: "recording_studio_publishable.load_config" do |_app|
      RecordingStudioPublishable::Hooks.run(:before_initialize, self)
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

      RecordingStudioPublishable::Hooks.run(:on_configuration, RecordingStudioPublishable.configuration)
    rescue StandardError
      nil
    end

    initializer "recording_studio_publishable.after_initialize",
                after: "recording_studio_publishable.load_config" do |_app|
      RecordingStudioPublishable::Hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_publishable.extensions" do
      engine = self

      config.to_prepare do
        RecordingStudioPublishable.install_recording_capabilities!
        engine.send(:register_publishable_recordable_type)
      end
    end

    private

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
