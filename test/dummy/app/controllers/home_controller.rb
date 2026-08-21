class HomeController < ApplicationController
  def index
    @publishable_parent_recordings = publishable_parent_recordings
  end

  private

  def publishable_parent_recordings
    RecordingStudio::Recording.where(recordable_type: %w[Page Article]).includes(:recordable, :parent_recording).order(:created_at, :id)
  end
end
