# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"

class PublishableLifecycleNotificationsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ActiveJob::Base.queue_adapter = :test
    @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Lifecycle workspace"))
    @parent_recording = RecordingStudio::Recording.create!(
      recordable: Article.create!(title: "Launch kit"),
      parent_recording: @root
    )
    @actor = User.create!(
      email: "lifecycle-#{SecureRandom.hex(4)}@example.com",
      password: "LifecyclePassword!2026",
      password_confirmation: "LifecyclePassword!2026"
    )
    @captured = Hash.new { |hash, key| hash[key] = [] }
    @subscribers = RecordingStudioPublishable::LifecycleNotifications::EVENTS.map do |kind, name|
      ActiveSupport::Notifications.subscribe(name) do |*args|
        @captured[kind] << ActiveSupport::Notifications::Event.new(*args).payload
      end
    end
  end

  teardown do
    Array(@subscribers).each { |subscriber| ActiveSupport::Notifications.unsubscribe(subscriber) }
    Current.actor = nil if defined?(Current)
  end

  test "host apps can subscribe to published without Publishable knowing about them" do
    result = publish(transition: "publish")

    assert result.success?
    assert_equal 1, @captured[:published].size
    assert_equal @parent_recording.id, @captured[:published].first[:recording_id]
    assert_equal "Article", @captured[:published].first[:recordable_type]
  end

  test "publish transition emits published after commit with payload shape" do
    freeze_time do
      result = publish(transition: "publish")

      assert result.success?
      assert_equal 1, @captured[:published].size
      assert_empty @captured[:unpublished]
      assert_empty @captured[:revised]

      payload = @captured[:published].first
      publishable = @parent_recording.reload.current_publishable

      assert_equal 1, payload[:schema_version]
      assert_equal @parent_recording.id, payload[:recording_id]
      assert_equal "Article", payload[:recordable_type]
      assert_equal @parent_recording.recordable_id, payload[:recordable_id]
      assert_equal @parent_recording.publishable_child_recording.id, payload[:publishable_recording_id]
      assert_equal publishable.id, payload[:publishable_id]
      assert_nil payload[:previous_publishable_id]
      assert_equal "User", payload[:actor_type]
      assert_equal @actor.id, payload[:actor_id]
      assert_equal "write", payload[:source]
      refute payload.dig(:previous_state, :currently_published)
      assert payload.dig(:current_state, :currently_published)
      assert_equal "published", payload.dig(:current_state, :status)
      assert_in_delta Time.current.to_i, payload[:occurred_at].to_i, 1
    end
  end

  test "unpublish transition emits unpublished" do
    publish(transition: "publish")
    @captured.clear

    result = publish(transition: "unpublish")

    assert result.success?
    assert_equal 1, @captured[:unpublished].size
    assert_empty @captured[:published]
    refute @captured[:unpublished].first.dig(:current_state, :currently_published)
    assert @captured[:unpublished].first.dig(:previous_state, :currently_published)
  end

  test "updating a live publication emits revised and not another published" do
    publish(transition: "publish")
    @captured.clear

    result = update_publishable(slug: "launch-kit", seo_title: "Launch kit SEO")

    assert result.success?
    assert_equal 1, @captured[:revised].size
    assert_empty @captured[:published]
    assert_empty @captured[:unpublished]
    assert @captured[:revised].first.dig(:current_state, :currently_published)
    refute_equal(
      @captured[:revised].first[:previous_publishable_id],
      @captured[:revised].first[:publishable_id]
    )
  end

  test "no-op unpublish of a draft emits nothing" do
    update_publishable(slug: "draft-kit", status: "draft")
    @captured.clear

    result = publish(transition: "unpublish")

    assert result.success?
    assert_empty @captured[:published]
    assert_empty @captured[:unpublished]
    assert_empty @captured[:revised]
  end

  test "no-op live update with the same fields emits nothing" do
    update_publishable(slug: "same-kit", status: "published", seo_title: "Same")
    @captured.clear

    result = update_publishable(slug: "same-kit", status: "published", seo_title: "Same")

    assert result.success?
    assert_empty @captured[:published]
    assert_empty @captured[:unpublished]
    assert_empty @captured[:revised]
  end

  test "scheduling a future publish does not emit published until the window job runs" do
    freeze_time do
      publish_at = 2.days.from_now

      assert_enqueued_with(
        job: RecordingStudioPublishable::WindowTransitionJob,
        args: [@parent_recording.id.to_s, "publish", publish_at.iso8601]
      ) do
        result = update_publishable(
          slug: "scheduled-kit",
          status: "published",
          publish_at: publish_at,
          time_zone: "UTC"
        )

        assert result.success?
      end

      assert_empty @captured[:published]
      assert_empty @captured[:unpublished]
      refute @parent_recording.reload.currently_published?

      RecordingStudioPublishable::WindowTransitionJob.perform_now(
        @parent_recording.id, "publish", publish_at.iso8601
      )
      assert_empty @captured[:published]

      travel publish_at - Time.current
      RecordingStudioPublishable::WindowTransitionJob.perform_now(
        @parent_recording.id, "publish", publish_at.iso8601
      )

      assert_equal 1, @captured[:published].size
      assert_equal "scheduled", @captured[:published].first[:source]
      assert @captured[:published].first.dig(:current_state, :currently_published)
    end
  end

  test "scheduled unpublish job emits unpublished when the window closes" do
    freeze_time do
      publish_at = 1.hour.ago
      unpublish_at = 2.days.from_now

      update_publishable(
        slug: "expiring-kit",
        status: "published",
        publish_at: publish_at,
        unpublish_at: unpublish_at,
        time_zone: "UTC"
      )
      @captured.clear

      travel unpublish_at - Time.current
      RecordingStudioPublishable::WindowTransitionJob.perform_now(
        @parent_recording.id, "unpublish", unpublish_at.iso8601
      )

      assert_equal 1, @captured[:unpublished].size
      assert_equal "scheduled", @captured[:unpublished].first[:source]
      refute @captured[:unpublished].first.dig(:current_state, :currently_published)
    end
  end

  test "scheduled job is a no-op when the window no longer matches" do
    freeze_time do
      publish_at = 2.days.from_now
      update_publishable(slug: "moved-kit", status: "published", publish_at: publish_at, time_zone: "UTC")
      publish(transition: "publish")
      @captured.clear

      travel 2.days
      RecordingStudioPublishable::WindowTransitionJob.perform_now(
        @parent_recording.id, "publish", publish_at.iso8601
      )

      assert_empty @captured[:published]
      assert_empty @captured[:unpublished]
    end
  end

  test "rolled back publish does not emit" do
    Article.transaction do
      publish(transition: "publish")
      assert_empty @captured[:published]
      raise ActiveRecord::Rollback
    end

    assert_empty @captured[:published]
    assert_empty @captured[:unpublished]
    refute @parent_recording.reload.currently_published?
  end

  test "failed update does not emit" do
    result = update_publishable(slug: "broken-kit", status: "published", publish_at: "not-a-time")

    assert result.failure?
    assert_empty @captured[:published]
    assert_empty @captured[:unpublished]
    assert_empty @captured[:revised]
  end

  private

  def publish(transition:)
    RecordingStudioPublishable::Services::Publishables::Transition.call(
      parent_recording: @parent_recording,
      transition: transition,
      actor: @actor
    )
  end

  def update_publishable(**attributes)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: @parent_recording,
      attributes: attributes,
      actor: @actor
    )
  end
end
