# frozen_string_literal: true

require "test_helper"

class ActorResolverTest < Minitest::Test
  def setup
    @defined_current = false

    unless Object.const_defined?(:Current)
      Object.const_set(:Current, Class.new)
      @defined_current = true
    end

    unless Current.respond_to?(:actor) && Current.respond_to?(:actor=)
      Current.singleton_class.class_eval { attr_accessor :actor }
    end

    @previous_actor = Current.actor
  end

  def teardown
    Current.actor = @previous_actor if Object.const_defined?(:Current) && Current.respond_to?(:actor=)
    Object.send(:remove_const, :Current) if @defined_current
  end

  def test_resolve_actor_returns_explicit_actor_when_provided
    explicit_actor = Object.new
    Current.actor = Object.new

    resolved = RecordingStudio::ActorResolver.resolve_actor.call(explicit_actor)

    assert_same explicit_actor, resolved
  end

  def test_resolve_actor_falls_back_to_current_actor
    fallback_actor = Object.new
    Current.actor = fallback_actor

    resolved = RecordingStudio::ActorResolver.resolve_actor.call

    assert_same fallback_actor, resolved
  end
end
