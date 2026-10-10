# frozen_string_literal: true

require "test_helper"
require "active_support/notifications"

class LifecycleNotificationsTest < Minitest::Test
  Snapshot = RecordingStudioPublishable::LifecycleNotifications::Snapshot

  def setup
    @events = []
    @subscriber = RecordingStudioPublishable.subscribe(:published) do |event|
      @events << event
    end
  end

  def teardown
    ActiveSupport::Notifications.unsubscribe(@subscriber)
  end

  def test_event_names_are_stable
    names = RecordingStudioPublishable::LifecycleNotifications::EVENTS

    assert_equal "published.recording_studio_publishable", names.fetch(:published)
    assert_equal "unpublished.recording_studio_publishable", names.fetch(:unpublished)
    assert_equal "revised.recording_studio_publishable", names.fetch(:revised)
  end

  def test_subscribe_wraps_notifications_with_an_event
    RecordingStudioPublishable::LifecycleNotifications.instrument!(
      :published,
      recording_id: "rec-1",
      source: "write"
    )

    assert_equal 1, @events.size
    assert_instance_of ActiveSupport::Notifications::Event, @events.first
    assert_equal "published.recording_studio_publishable", @events.first.name
    assert_equal "rec-1", @events.first.payload[:recording_id]
    assert_equal "write", @events.first.payload[:source]
  end

  def test_subscribe_rejects_unknown_events
    error = assert_raises(ArgumentError) do
      RecordingStudioPublishable.subscribe(:trashed) { nil }
    end

    assert_match(/unknown lifecycle event/, error.message)
  end

  def test_event_for_detects_publish_unpublish_and_revision
    draft = snapshot(currently_published: false, fingerprint: ["draft"])
    live = snapshot(currently_published: true, fingerprint: ["live"])
    live_revised = snapshot(currently_published: true, fingerprint: ["live-2"])

    notifications = RecordingStudioPublishable::LifecycleNotifications

    assert_equal :published, notifications.event_for(draft, live)
    assert_equal :unpublished, notifications.event_for(live, draft)
    assert_equal :revised, notifications.event_for(live, live_revised)
    assert_nil notifications.event_for(draft, draft)
    assert_nil notifications.event_for(live, live)
    assert_nil notifications.event_for(draft, snapshot(currently_published: false, fingerprint: ["other"]))
  end

  def test_subscribe_accepts_full_event_name
    payloads = []
    subscriber = RecordingStudioPublishable.subscribe(
      "unpublished.recording_studio_publishable"
    ) do |_n, _s, _f, _i, payload|
      payloads << payload
    end

    RecordingStudioPublishable::LifecycleNotifications.instrument!(:unpublished, recording_id: "rec-2")

    assert_equal [{ recording_id: "rec-2" }], payloads
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  private

  def snapshot(currently_published:, fingerprint:)
    Snapshot.new(
      nil, nil, currently_published ? "published" : "draft", currently_published, false, nil, nil, fingerprint
    )
  end
end
