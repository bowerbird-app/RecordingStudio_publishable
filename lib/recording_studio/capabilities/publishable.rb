# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Publishable
      def self.to(**options)
        normalized = capability_options(options)
        RecordingStudio::Capabilities.include_for(:publishable, **normalized) do |base|
          apply_recordable!(base, normalized)
        end
      end

      def self.capability_options(options)
        options.to_h.transform_keys(&:to_sym)
      end

      def self.apply_recordable!(base, options)
        unless base < RecordingStudioPublishable::ParentRecordable
          base.include(RecordingStudioPublishable::ParentRecordable)
        end
        RecordingStudioPublishable::ParentRecordable.configure!(base, **options)
        ensure_child_recordable_registered!
      end

      def self.ensure_child_recordable_registered!
        return unless defined?(RecordingStudio::Recording)
        return unless RecordingStudio::Recording.respond_to?(:delegated_type)

        type = "RecordingStudioPublishable::Publishable"
        existing = Array(RecordingStudio.configuration.recordable_types).map do |recordable_type|
          recordable_type.is_a?(Class) ? recordable_type.name : recordable_type.to_s
        end
        return if existing.include?(type)

        RecordingStudio.register_recordable_type(type)
      end

      module RecordingMethods
        include RecordingStudio::Capability if defined?(RecordingStudio::Capability)
        include RecordingStudioPublishable::RecordingExtensions
      end
    end
  end
end

RecordingStudio.register_capability(
  :publishable,
  recording_methods: RecordingStudio::Capabilities::Publishable::RecordingMethods,
  source: "recording_studio_publishable",
  child_recordables: ["RecordingStudioPublishable::Publishable"]
)
