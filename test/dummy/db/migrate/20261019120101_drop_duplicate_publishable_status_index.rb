# frozen_string_literal: true

require "recording_studio_publishable/publishable_child_index"

class DropDuplicatePublishableStatusIndex < ActiveRecord::Migration[8.1]
  include RecordingStudioPublishable::PublishableChildIndex::V1

  # Created with the publishables table. Fresh installs keep this index.
  ORIGINAL_INDEX = "index_rs_publishables_on_state_window"
  # Added by 20260516000100 on the same columns and options. Never drop ORIGINAL_INDEX.
  DUPLICATE_INDEX = "index_publishables_on_status_and_publish_times"
  PUBLISHABLES = :recording_studio_publishable_publishables
  STATUS_COLUMNS = %w[status publish_at unpublish_at].freeze

  disable_ddl_transaction!

  def up
    refuse_invalid_unique_child_index!
    return unless original_status_index_valid?
    return unless index_exists?(PUBLISHABLES, name: DUPLICATE_INDEX)

    with_concurrent_lock_timeout do
      remove_index PUBLISHABLES,
                   name: DUPLICATE_INDEX,
                   algorithm: :concurrently,
                   if_exists: true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, <<~MSG
      Refusing to recreate duplicate index #{DUPLICATE_INDEX}.
      #{ORIGINAL_INDEX} is the index this migration keeps.
      Putting the duplicate back would add a second identical index on a live table.
      Recreate it concurrently only if you have a reason to:

        CREATE INDEX CONCURRENTLY IF NOT EXISTS #{DUPLICATE_INDEX}
          ON recording_studio_publishable_publishables (status, publish_at, unpublish_at);
    MSG
  end

  private

  def original_status_index_valid?
    connection.indexes(PUBLISHABLES).any? do |index|
      index.name == ORIGINAL_INDEX && plain_status_index?(index)
    end
  end

  def plain_status_index?(index)
    [
      Array(index.columns) == STATUS_COLUMNS,
      index.valid?,
      index.using.to_s == "btree",
      index.opclasses.blank?,
      index.orders.blank?,
      index.include.blank?,
      !index.unique,
      index.where.blank?
    ].all?
  end
end
