# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../../test_helper"
require_relative "../../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  module Services
    module Publishables
      class ResolveTest < ActiveSupport::TestCase
        setup do
          @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Workspace"))
          @parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Published"),
                                                                 parent_recording: @root)
          @publishable_recording = Update.call(
            parent_recording: @parent_recording,
            attributes: { slug: "published", status: "published" }
          ).value
        end

        test "resolves currently published records" do
          result = Resolve.call(uuid: @publishable_recording.id, slug: "published")

          assert result.success?
          assert_equal @parent_recording.id, result.value[:parent_recording].id
        end

        test "rejects stale slugs" do
          result = Resolve.call(uuid: @publishable_recording.id, slug: "old-slug")

          assert result.failure?
          assert_equal "Publishable slug is stale", result.error
        end
      end
    end
  end
end
