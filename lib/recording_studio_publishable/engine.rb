# frozen_string_literal: true

module RecordingStudioPublishable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioPublishable

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
        engine.send(:register_publishable_recordable_type)
        engine.send(:extend_recording_model)
      end
    end

    private

    def register_publishable_recordable_type
      return unless defined?(RecordingStudio) && RecordingStudio.respond_to?(:configuration)
      return unless RecordingStudio.configuration.respond_to?(:recordable_types)

      recordable_types = normalized_recordable_types
      publishable_type = RecordingStudioPublishable::Publishable.name
      return if recordable_types.include?(publishable_type)

      RecordingStudio.configuration.recordable_types = (recordable_types + [publishable_type]).uniq
    end

    def normalized_recordable_types
      Array(RecordingStudio.configuration.recordable_types).map do |recordable_type|
        recordable_type.is_a?(Class) ? recordable_type.name : recordable_type.to_s
      end
    end

    def extend_recording_model
      return unless defined?(RecordingStudio::Recording)
      return if RecordingStudio::Recording < RecordingStudioPublishable::RecordingExtensions

      RecordingStudio::Recording.include RecordingStudioPublishable::RecordingExtensions
    end
  end
end
