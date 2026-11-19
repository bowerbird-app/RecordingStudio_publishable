# frozen_string_literal: true

# This migration comes from recording_studio_api (originally 20261117000024)
class AddOwnerToRecordingStudioApiApiClients < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_api_api_clients, :owner_type, :string
    add_column :recording_studio_api_api_clients, :owner_id, :uuid
    add_index :recording_studio_api_api_clients,
              %i[owner_type owner_id],
              name: "index_rs_api_clients_on_owner"
  end
end
