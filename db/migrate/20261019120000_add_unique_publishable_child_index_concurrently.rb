# frozen_string_literal: true

require "recording_studio_publishable/publishable_child_index"

class AddUniquePublishableChildIndexConcurrently < ActiveRecord::Migration[8.1]
  include RecordingStudioPublishable::PublishableChildIndex

  disable_ddl_transaction!

  def up
    if (index = find_index(RECORDINGS, UNIQUE_CHILD_INDEX))
      raise unique_child_index_drift_message(index) unless unique_child_index_shape?(index)
      return if index_valid?(RECORDINGS, UNIQUE_CHILD_INDEX)

      raise preexisting_invalid_unique_child_index_message
    end

    create_unique_child_index!
  end

  def down
    raise ActiveRecord::IrreversibleMigration, <<~MSG.squish
      Refusing to drop unique index #{UNIQUE_CHILD_INDEX}.
      Hosts that already installed Publishable created it inside the
      publishables table migration. Dropping it would allow two publishable
      children under one parent.
    MSG
  end

  private

  def create_unique_child_index!
    with_concurrent_lock_timeout do
      add_index RECORDINGS,
                :parent_recording_id,
                unique: true,
                name: UNIQUE_CHILD_INDEX,
                where: unique_child_index_where_clause,
                algorithm: :concurrently,
                if_not_exists: true
    end
    return if index_valid?(RECORDINGS, UNIQUE_CHILD_INDEX)

    drop_invalid_unique_child_index
    raise invalid_index_created_by_this_run_message
  rescue ActiveRecord::StatementInvalid => e
    raise unless invalid_unique_child_index?

    drop_invalid_unique_child_index
    raise invalid_index_created_by_this_run_message(e)
  end
end
