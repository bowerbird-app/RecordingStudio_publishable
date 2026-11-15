# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../../test_helper"
require_relative "../../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  module Services
    module Publishables
      class EnsureChildTest < ActiveSupport::TestCase
        setup do
          @page = Page.create!(title: "Published page")
          @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Workspace"))
          @parent_recording = RecordingStudio::Recording.create!(recordable: @page, parent_recording: @root)
        end

        test "creates one publishable child recording per parent" do
          result = EnsureChild.call(parent_recording: @parent_recording)

          assert result.success?
          assert_equal RecordingStudioPublishable::Publishable.name, result.value.recordable_type
          assert_equal @parent_recording, result.value.parent_recording
          assert_equal result.value.id, @parent_recording.reload.publishable_child_recording.id
        end

        test "returns the existing child recording when called again" do
          first = EnsureChild.call(parent_recording: @parent_recording).value
          second = EnsureChild.call(parent_recording: @parent_recording).value

          assert_equal first.id, second.id
        end

        test "returns the kept child when a concurrent create loses the slot" do
          existing = EnsureChild.call(parent_recording: @parent_recording).value
          calls = 0
          real = RecordingStudioPublishable::RecordingExtensions.instance_method(:publishable_child_recording)
          @parent_recording.define_singleton_method(:publishable_child_recording) do
            calls += 1
            next nil if calls == 1

            real.bind_call(self)
          end

          result = EnsureChild.call(parent_recording: @parent_recording)
          children = publishable_children

          assert result.success?
          assert_equal existing.id, result.value.id
          assert_equal 1, children.count
        end

        test "recording a second publishable child raises SlotTaken" do
          EnsureChild.call(parent_recording: @parent_recording)
          root = @parent_recording.root_recording || @parent_recording

          error = assert_raises(RecordingStudio::SlotTaken) do
            root.record(
              RecordingStudioPublishable::Publishable,
              parent_recording: @parent_recording
            ) do |publishable|
              publishable.slug = "second-child"
              publishable.status = :draft
            end
          end

          assert_match(/already has a recording/, error.message)
          assert_equal 1, publishable_children.count
        end

        test "a trashed publishable child still holds the slot" do
          existing = EnsureChild.call(parent_recording: @parent_recording).value
          RecordingStudio::Recording.where(id: existing.id).update_all(trashed_at: Time.current)

          result = EnsureChild.call(parent_recording: @parent_recording)

          assert result.failure?
          assert_match(/already has a recording/, result.error)
          assert_equal 1, publishable_children.count
        end

        test "rejects a publishable recording as the parent" do
          publishable_recording = EnsureChild.call(parent_recording: @parent_recording).value

          result = EnsureChild.call(parent_recording: publishable_recording)

          assert result.failure?
          assert_equal "Publishable recordings cannot own publishable children", result.error
          assert_nil publishable_recording.reload.publishable_child_recording
        end

        private

        def publishable_children
          RecordingStudio::Recording.unscoped.where(
            parent_recording_id: @parent_recording.id,
            recordable_type: RecordingStudioPublishable::Publishable.name
          )
        end
      end
    end
  end
end
