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
      end
    end
  end
end
