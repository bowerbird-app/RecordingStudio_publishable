# frozen_string_literal: true

require "test_helper"

class TrashedAtTest < Minitest::Test
  def test_merge_active_skips_trashed_at_when_the_column_is_absent
    RecordingStudioPublishable::TrashedAt.stub(:column?, false) do
      assert_equal({ id: "abc" }, RecordingStudioPublishable::TrashedAt.merge_active(id: "abc"))
      assert_nil RecordingStudioPublishable::TrashedAt.active_sql("publishable_recordings")
    end
  end

  def test_merge_active_adds_trashed_at_when_the_column_exists
    RecordingStudioPublishable::TrashedAt.stub(:column?, true) do
      assert_equal({ id: "abc", trashed_at: nil }, RecordingStudioPublishable::TrashedAt.merge_active(id: "abc"))
      assert_equal "publishable_recordings.trashed_at IS NULL",
                   RecordingStudioPublishable::TrashedAt.active_sql("publishable_recordings")
    end
  end
end
