# frozen_string_literal: true

class AddIndexesToPublishable < ActiveRecord::Migration[6.0]
  INDEX_NAME = "index_publishables_on_status_and_publish_times"
  STATUS_COLUMNS = %w[status publish_at unpublish_at].freeze

  def up
    return if equivalent_status_index?

    add_index :recording_studio_publishable_publishables, STATUS_COLUMNS,
              name: INDEX_NAME,
              if_not_exists: true
  end

  def down
    return unless index_exists?(:recording_studio_publishable_publishables, name: INDEX_NAME)

    remove_index :recording_studio_publishable_publishables, name: INDEX_NAME
  end

  private

  # Same table, columns, and options as index_rs_publishables_on_state_window.
  # A second index with a different name is still a duplicate.
  # Expression indexes report columns as a String. Array() does not call String#map.
  def equivalent_status_index?
    connection.indexes(:recording_studio_publishable_publishables).any? do |index|
      plain_status_index?(index)
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
