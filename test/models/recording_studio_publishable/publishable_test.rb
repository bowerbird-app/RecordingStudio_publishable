# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../../test_helper"
require_relative "../../dummy/config/environment"
require "rails/test_help"

module RecordingStudioPublishable
  class PublishableTest < ActiveSupport::TestCase
    test "currently_published? respects publish and unpublish timestamps" do
      publishable = Publishable.new(status: :published, publish_at: 1.hour.ago, unpublish_at: 1.hour.from_now,
                                    slug: "demo")

      assert publishable.currently_published?
      assert publishable.published?
      refute publishable.unpublished?
    end

    test "published? is false outside the live window and unpublished? tracks prior live content" do
      publishable = Publishable.new(status: :draft, publish_at: 2.hours.ago, unpublish_at: 1.hour.ago,
                                    slug: "demo")

      refute publishable.currently_published?
      refute publishable.published?
      assert publishable.unpublished?
      assert publishable.previously_published?
    end

    test "scheduled_for_future? is true only for published future records" do
      publishable = Publishable.new(status: :published, publish_at: 1.hour.from_now, slug: "demo")

      assert publishable.scheduled_for_future?
      refute publishable.currently_published?
    end

    test "published records become currently published once publish_at has passed" do
      publishable = Publishable.new(status: :published, publish_at: 10.minutes.ago, slug: "demo")

      assert publishable.currently_published?
      assert publishable.published?
      refute publishable.scheduled_for_future?
    end

    test "publish window validation rejects inverted windows" do
      publishable = Publishable.new(slug: "demo", status: :published, publish_at: 2.hours.from_now,
                                    unpublish_at: 1.hour.from_now)

      refute publishable.valid?
      assert_includes publishable.errors[:unpublish_at], "must be later than publish at"
    end

    test "legacy status values are rejected" do
      publishable = Publishable.new(status: "scheduled", slug: "demo")

      refute publishable.valid?
      assert_includes publishable.errors[:status], "is not included in the list"

      publishable.status = "unpublished"

      refute publishable.valid?
      assert_includes publishable.errors[:status], "is not included in the list"
    end

    test "slug rejects unsafe characters" do
      publishable = Publishable.new(status: :draft, slug: "bad/slug")

      refute publishable.valid?
      assert_includes publishable.errors[:slug], "must use URL-safe lowercase slug segments"
    end

    test "effective time zone falls back to the configured default" do
      original_time_zone = RecordingStudioPublishable.configuration.default_time_zone
      RecordingStudioPublishable.configuration.default_time_zone = "Pacific Time (US & Canada)"

      publishable = Publishable.new(status: :draft, slug: "demo")

      assert_equal "Pacific Time (US & Canada)", publishable.effective_time_zone
    ensure
      RecordingStudioPublishable.configuration.default_time_zone = original_time_zone
    end

    test "social image selection api is available" do
      publishable = Publishable.new(status: :draft, slug: "demo")

      assert_respond_to publishable, :social_image_attachment_recording
      assert_respond_to publishable, :social_image_attachment
    end

    test "social image helpers reflect attachment selection state" do
      publishable = Publishable.new(status: :draft, slug: "demo")

      assert publishable.social_image_supported?
      refute publishable.social_image_attached?
      assert_nil publishable.social_image_attachment
    end
  end
end
