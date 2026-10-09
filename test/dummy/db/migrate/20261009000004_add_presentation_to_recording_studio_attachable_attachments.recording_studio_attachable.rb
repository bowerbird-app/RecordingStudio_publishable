# frozen_string_literal: true

# This migration comes from recording_studio_attachable (originally 20261001140000)

class AddPresentationToRecordingStudioAttachableAttachments < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_attachable_attachments, :caption, :text
    add_column :recording_studio_attachable_attachments, :credit, :text
    add_column :recording_studio_attachable_attachments, :alt_text, :text
  end
end
