# frozen_string_literal: true

class AddDeviceMetadataToRecordingStudioRootSwitchableSelections < ActiveRecord::Migration[8.1]
  def change
    change_table :recording_studio_root_switchable_selections, bulk: true do |t|
      t.string :device_label, limit: 255
      t.string :device_platform, limit: 255
      t.string :device_browser, limit: 255
      t.string :device_type, limit: 255
      t.text :user_agent
    end
  end
end
