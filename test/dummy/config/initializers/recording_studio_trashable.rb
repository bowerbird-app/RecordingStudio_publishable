# frozen_string_literal: true

# Pinned API and Admin still call this class method. Trashable 0.16.0 removed it.
Rails.application.reloader.to_prepare do
  RecordingStudio::Recording.define_singleton_method(:recording_studio_trashable_kept_sql) do |table = "recording_studio_recordings"|
    RecordingStudio.kept_sql(table)
  end
end
