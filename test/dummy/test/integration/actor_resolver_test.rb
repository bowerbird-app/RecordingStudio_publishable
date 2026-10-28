# frozen_string_literal: true

require "test_helper"

class ActorResolverTest < ActiveSupport::TestCase
  setup do
    @previous_actor = Current.actor
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "resolve_actor returns explicit actor when provided" do
    explicit_actor = User.new
    Current.actor = User.new

    resolved = RecordingStudio::ActorResolver.resolve_actor.call(explicit_actor)

    assert_same explicit_actor, resolved
  end

  test "resolve_actor falls back to Current.actor" do
    fallback_actor = User.new
    Current.actor = fallback_actor

    resolved = RecordingStudio::ActorResolver.resolve_actor.call

    assert_same fallback_actor, resolved
  end
end
