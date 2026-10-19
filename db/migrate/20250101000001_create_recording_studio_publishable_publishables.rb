# frozen_string_literal: true

class CreateRecordingStudioPublishablePublishables < ActiveRecord::Migration[8.1]
  CANONICAL_URL_INDEX = "index_rs_publishables_on_canonical_url"
  SLUG_INDEX = "index_rs_publishables_on_slug"

  # The unique partial index on recording_studio_recordings is built in
  # AddUniquePublishableChildIndexConcurrently. This migration also creates
  # the publishables table, which has to stay in one transaction.
  def change
    create_table :recording_studio_publishable_publishables, id: :uuid do |t|
      t.string :slug, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :publish_at
      t.datetime :unpublish_at
      t.string :time_zone
      t.string :seo_title
      t.text :seo_description
      t.string :canonical_url
      t.string :meta_robots
      t.string :social_title
      t.text :social_description
      t.timestamps
    end

    add_index :recording_studio_publishable_publishables, :slug, name: SLUG_INDEX
    add_index :recording_studio_publishable_publishables, %i[status publish_at unpublish_at],
              name: "index_rs_publishables_on_state_window"
    add_index :recording_studio_publishable_publishables, :canonical_url, name: CANONICAL_URL_INDEX
  end
end
