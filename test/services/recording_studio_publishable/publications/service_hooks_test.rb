# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../../test_helper"
require_relative "../../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  module Services
    module Publishables
      class ServiceHooksTest < ActiveSupport::TestCase
        setup do
          @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Workspace"))
          @parent_recording = RecordingStudio::Recording.create!(
            recordable: Article.create!(title: "Landing"),
            parent_recording: @root
          )
        end

        test "core registry hooks run for update and transition" do
          befores = []
          afters = []
          arounds = []
          direct_attributes = { slug: "core-hooks", status: "draft" }

          with_core_service_hooks do |hooks|
            hooks.before_service do |service_class, args|
              befores << [service_class, args]
            end
            hooks.after_service do |service_class, result|
              afters << [service_class, result]
            end
            hooks.around_service do |service, block|
              arounds << service
              block.call
            end

            updated = Update.call(parent_recording: @parent_recording, attributes: direct_attributes)
            published = Transition.call(parent_recording: @parent_recording, transition: "publish")

            assert updated.success?
            assert published.success?
          end

          assert_includes befores, [
            Update,
            { parent_recording_id: @parent_recording.id, attributes: direct_attributes }
          ]
          assert_includes befores, [Transition, {}]
          assert(afters.any? { |service_class, result| service_class == Update && result.success? })
          assert(afters.any? { |service_class, result| service_class == Transition && result.success? })
          assert_includes arounds.map(&:class), Update
          assert_includes arounds.map(&:class), Transition
        end

        private

        def with_core_service_hooks
          hooks = RecordingStudio.configuration.hooks
          registry = hooks.instance_variable_get(:@registry)
          snapshot = registry.transform_values(&:dup)

          yield hooks
        ensure
          restore_hook_registry(registry, snapshot)
        end

        def restore_hook_registry(registry, snapshot)
          return unless registry && snapshot

          (registry.keys - snapshot.keys).each { |name| registry.delete(name) }
          snapshot.each { |name, handlers| registry[name] = handlers }
        end
      end
    end
  end
end
