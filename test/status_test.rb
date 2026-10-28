# frozen_string_literal: true

require "test_helper"

class StatusTest < Minitest::Test
  FakePublishable = Struct.new(:scheduled, :published) do
    def scheduled_for_future?
      scheduled
    end

    def published_state?
      published
    end
  end

  def test_label_and_badge_style_for_each_state
    draft = FakePublishable.new(false, false)
    published = FakePublishable.new(false, true)
    scheduled = FakePublishable.new(true, true)

    assert_equal "Draft", RecordingStudioPublishable::Status.label(draft)
    assert_equal :info, RecordingStudioPublishable::Status.badge_style(draft)
    assert_equal "Published", RecordingStudioPublishable::Status.label(published)
    assert_equal :success, RecordingStudioPublishable::Status.badge_style(published)
    assert_equal "Scheduled", RecordingStudioPublishable::Status.label(scheduled)
    assert_equal :warning, RecordingStudioPublishable::Status.badge_style(scheduled)
  end
end
