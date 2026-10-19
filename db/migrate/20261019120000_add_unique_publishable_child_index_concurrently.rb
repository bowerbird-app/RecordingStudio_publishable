# frozen_string_literal: true

require "recording_studio_publishable/publishable_child_index"

# Swap steps for the unique publishable-child index. Kept beside the migration
# so a copied host file still contains the whole swap.
module AddUniquePublishableChildIndexSwap
  include RecordingStudioPublishable::PublishableChildIndex::V1

  def replacement_index_name
    "#{UNIQUE_CHILD_INDEX}_new"
  end

  def replacement_index_ready?(index = find_index(RECORDINGS, replacement_index_name))
    index&.valid? && unique_child_index_shape?(index)
  end

  # Build the looser index first, then drop the old one, then rename.
  # The table keeps a unique index for the whole swap.
  def swap_stricter_unique_child_index!
    create_replacement_unique_child_index!
    drop_stricter_unique_child_index!
    rename_replacement_unique_child_index!
  end

  def drop_stricter_unique_child_index!
    with_concurrent_lock_timeout do
      execute(<<~SQL.squish)
        DROP INDEX CONCURRENTLY #{schema_qualified_index_name(RECORDINGS, UNIQUE_CHILD_INDEX)}
      SQL
    end
  rescue ActiveRecord::QueryCanceled
    raise interrupted_swap_message
  end

  def interrupted_swap_message
    <<~MSG
      DROP INDEX CONCURRENTLY #{UNIQUE_CHILD_INDEX} was cancelled.
      #{replacement_index_name} is still in place.
      #{unique_child_index_repair_steps(UNIQUE_CHILD_INDEX)}
    MSG
  end

  def rename_replacement_unique_child_index!
    replacement = find_index(RECORDINGS, replacement_index_name)
    raise unique_child_index_drift_message(replacement) unless replacement_index_ready?(replacement)

    execute(<<~SQL.squish)
      ALTER INDEX #{schema_qualified_index_name(RECORDINGS, replacement_index_name)}
      RENAME TO #{connection.quote_table_name(UNIQUE_CHILD_INDEX)}
    SQL
  end

  def create_replacement_unique_child_index!
    replacement = find_index(RECORDINGS, replacement_index_name)
    if replacement
      raise unique_child_index_drift_message(replacement) unless unique_child_index_shape?(replacement)

      return if replacement.valid?
    end

    with_concurrent_lock_timeout do
      add_index RECORDINGS,
                :parent_recording_id,
                unique: true,
                name: replacement_index_name,
                where: unique_child_index_where_clause,
                algorithm: :concurrently,
                if_not_exists: true
    end
    return if index_valid?(RECORDINGS, replacement_index_name)

    drop_invalid_index(replacement_index_name)
    raise built_index_invalid_message(replacement_index_name)
  rescue ActiveRecord::StatementInvalid => e
    raise unless invalid_index?(replacement_index_name)

    drop_invalid_index(replacement_index_name)
    raise built_index_invalid_message(replacement_index_name, e)
  end
end

class AddUniquePublishableChildIndexConcurrently < ActiveRecord::Migration[8.1]
  include RecordingStudioPublishable::PublishableChildIndex::V1
  include AddUniquePublishableChildIndexSwap

  disable_ddl_transaction!

  def up
    index = find_index(RECORDINGS, UNIQUE_CHILD_INDEX)
    return adopt_existing_unique_child_index(index) if index
    return rename_replacement_unique_child_index! if replacement_index_ready?

    refuse_stray_replacement!
    drop_invalid_index(replacement_index_name)
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

  def adopt_existing_unique_child_index(index)
    if unique_child_index_shape?(index)
      return if index.valid?

      raise preexisting_invalid_unique_child_index_message
    end

    if stricter_unique_child_shape?(index)
      return swap_stricter_unique_child_index! if index.valid? || replacement_index_ready?

      raise preexisting_invalid_unique_child_index_message
    end

    raise unique_child_index_drift_message(index)
  end

  def refuse_stray_replacement!
    replacement = find_index(RECORDINGS, replacement_index_name)
    return unless replacement
    return if unique_child_index_shape?(replacement)

    raise unique_child_index_drift_message(replacement)
  end

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
