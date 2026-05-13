# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../../test_helper"
require_relative "../../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  module Services
    module Publishables
      class UpdateTest < ActiveSupport::TestCase
        setup do
          @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Workspace"))
          @parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Landing"), parent_recording: @root)
        end

        test "creates a revised publishable recordable with provided attributes" do
          result = Update.call(
            parent_recording: @parent_recording,
            attributes: {
              slug: "landing-page",
              status: "published",
              seo_title: "Landing page",
              canonical_url: "https://example.test/landing-page"
            }
          )

          assert result.success?
          publishable = result.value.recordable
          assert_equal "landing-page", publishable.slug
          assert_equal "published", publishable.status
          assert_equal "Landing page", publishable.seo_title
          assert_equal "https://example.test/landing-page", publishable.canonical_url
        end


        test "returns a failure when publish_at is invalid" do
          result = Update.call(
            parent_recording: @parent_recording,
            attributes: { slug: "landing-page", publish_at: "not-a-time" }
          )

          assert result.failure?
          assert_equal "Publish at is invalid", result.error
        end
      end
    end
  end
end
