# frozen_string_literal: true

module RecordingStudioPublishable
  # After-commit ActiveSupport::Notifications for public visibility changes.
  #
  # Recording Studio already emits `recordings.event_created` for every `revise`
  # / `log_event!`. That is snapshot history, not "this parent went live".
  # Service hooks run for every Update, in-process, and are not after-commit.
  # These events are the cross-gem signal: Publishable stays unaware of
  # Downloadable, Presskits, and other subscribers.
  module LifecycleNotifications
    NAMESPACE = "recording_studio_publishable"
    SCHEMA_VERSION = 1
    EVENTS = {
      published: "published.#{NAMESPACE}",
      unpublished: "unpublished.#{NAMESPACE}",
      revised: "revised.#{NAMESPACE}"
    }.freeze
    FINGERPRINT_ATTRIBUTES = %i[
      status slug publish_at unpublish_at seo_title seo_description
      canonical_url meta_robots social_title social_description
      social_image_attachment_recording_id
    ].freeze

    Snapshot = Data.define(
      :publishable_id,
      :publishable_recording_id,
      :status,
      :currently_published,
      :scheduled,
      :publish_at,
      :unpublish_at,
      :fingerprint
    ) do
      def to_payload
        {
          status: status,
          currently_published: currently_published,
          scheduled: scheduled,
          publish_at: publish_at,
          unpublish_at: unpublish_at
        }
      end
    end

    module_function

    def subscribe(name, &block)
      event_name = event_name_for(name)
      ActiveSupport::Notifications.subscribe(event_name) do |*args|
        if block.arity == 1
          block.call(ActiveSupport::Notifications::Event.new(*args))
        else
          block.call(*args)
        end
      end
    end

    def event_name_for(name)
      value = name.to_s
      return value if EVENTS.value?(value)

      EVENTS.fetch(name.to_sym)
    rescue KeyError
      raise ArgumentError, "unknown lifecycle event: #{name.inspect}"
    end

    def snapshot_for(parent_recording)
      child = parent_recording&.publishable_child_recording
      publishable = child&.recordable
      return empty_snapshot if publishable.blank?

      Snapshot.new(
        publishable_id: publishable.id,
        publishable_recording_id: child.id,
        status: publishable.status,
        currently_published: publishable.currently_published?,
        scheduled: publishable.scheduled_for_future?,
        publish_at: publishable.publish_at,
        unpublish_at: publishable.unpublish_at,
        fingerprint: fingerprint_for(publishable)
      )
    end

    def after_write!(parent_recording:, previous:, actor: nil, source: "write")
      current = snapshot_for(parent_recording)
      enqueue_window_jobs(parent_recording, current)
      event = event_for(previous, current)
      return if event.nil?

      payload = payload_for(
        previous: previous,
        current: current,
        parent_recording: parent_recording,
        actor: actor,
        source: source
      )
      emit_after_commit(event, payload)
    end

    def emit_scheduled!(parent_recording_id:, transition:, expected_at:)
      parent_recording = RecordingStudio::Recording.find_by(id: parent_recording_id)
      return if parent_recording.blank?

      current = snapshot_for(parent_recording)
      expected = parse_time(expected_at)
      return if expected.blank?

      previous, event = scheduled_transition(current, transition, expected)
      return if event.nil?

      payload = payload_for(
        previous: previous,
        current: current,
        parent_recording: parent_recording,
        actor: nil,
        source: "scheduled"
      )
      emit_after_commit(event, payload)
    end

    def empty_snapshot
      Snapshot.new(nil, nil, nil, false, false, nil, nil, nil)
    end

    def event_for(previous, current)
      was_live = previous&.currently_published || false
      now_live = current.currently_published

      return :published if !was_live && now_live
      return :unpublished if was_live && !now_live
      return :revised if was_live && now_live && previous.fingerprint != current.fingerprint

      nil
    end

    def instrument!(event, payload)
      ActiveSupport::Notifications.instrument(EVENTS.fetch(event), payload)
    end

    def emit_after_commit(event, payload)
      if defined?(ActiveRecord) && ActiveRecord.respond_to?(:after_all_transactions_commit)
        ActiveRecord.after_all_transactions_commit { instrument!(event, payload) }
      else
        instrument!(event, payload)
      end
    end

    def payload_for(previous:, current:, parent_recording:, actor:, source:)
      {
        schema_version: SCHEMA_VERSION,
        recording_id: parent_recording.id,
        recordable_type: parent_recording.recordable_type,
        recordable_id: parent_recording.recordable_id,
        publishable_recording_id: current.publishable_recording_id,
        publishable_id: current.publishable_id,
        previous_publishable_id: previous&.publishable_id,
        actor_type: actor_type_for(actor),
        actor_id: actor.respond_to?(:id) ? actor.id : nil,
        previous_state: (previous || empty_snapshot).to_payload,
        current_state: current.to_payload,
        occurred_at: Time.current,
        source: source.to_s
      }
    end

    def enqueue_window_jobs(parent_recording, current)
      enqueue_window_job(parent_recording.id, "publish", current.publish_at)
      enqueue_window_job(parent_recording.id, "unpublish", current.unpublish_at)
    end

    def enqueue_window_job(parent_recording_id, transition, run_at)
      return if run_at.blank? || !run_at.future?
      return unless defined?(ActiveJob::Base)

      WindowTransitionJob.set(wait_until: run_at).perform_later(
        parent_recording_id.to_s,
        transition.to_s,
        run_at.iso8601
      )
    end

    def scheduled_transition(current, transition, expected)
      case transition.to_s
      when "publish"
        return unless current.currently_published
        return unless times_match?(current.publish_at, expected)

        previous = empty_snapshot.with(
          status: current.status,
          currently_published: false,
          scheduled: true,
          publish_at: current.publish_at,
          unpublish_at: current.unpublish_at,
          fingerprint: current.fingerprint
        )
        [previous, :published]
      when "unpublish"
        return if current.currently_published
        return unless times_match?(current.unpublish_at, expected)

        previous = current.with(currently_published: true, scheduled: false)
        [previous, :unpublished]
      end
    end

    def fingerprint_for(publishable)
      FINGERPRINT_ATTRIBUTES.map do |attribute|
        value = publishable.public_send(attribute)
        value.respond_to?(:iso8601) ? value.iso8601(0) : value
      end
    end

    def actor_type_for(actor)
      return if actor.nil?
      return actor.class.base_class.name if actor.class.respond_to?(:base_class)

      actor.class.name
    end

    def parse_time(value)
      return value if value.respond_to?(:to_i) && value.respond_to?(:future?)
      return if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      Time.zone.parse(value.to_s) if Time.respond_to?(:zone)
    end

    def times_match?(left, right)
      left.present? && right.present? && left.to_i == right.to_i
    end
  end
end
