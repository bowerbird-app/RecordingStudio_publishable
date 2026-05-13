# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../test_helper"
require_relative "../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  class PublishableTest < ActiveSupport::TestCase
    test "currently_published? respects publish and unpublish timestamps" do
      publishable = Publishable.new(status: :published, publish_at: 1.hour.ago, unpublish_at: 1.hour.from_now, slug: "demo")

      assert publishable.currently_published?
    end

    test "scheduled_for_future? is true only for scheduled future records" do
      publishable = Publishable.new(status: :scheduled, publish_at: 1.hour.from_now, slug: "demo")

      assert publishable.scheduled_for_future?
      refute publishable.currently_published?
    end

    test "publish window validation rejects inverted windows" do
      publishable = Publishable.new(slug: "demo", status: :scheduled, publish_at: 2.hours.from_now, unpublish_at: 1.hour.from_now)

      refute publishable.valid?
      assert_includes publishable.errors[:unpublish_at], "must be later than publish at"
    end


    test "slug rejects unsafe characters" do
      publishable = Publishable.new(status: :draft, slug: "bad/slug")

      refute publishable.valid?
      assert_includes publishable.errors[:slug], "must use URL-safe lowercase slug segments"
    end
  end
end
