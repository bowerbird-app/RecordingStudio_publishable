class HomeController < ApplicationController
  def index
    @page_recordings = page_recordings
  end

  private

  def page_recordings
    RecordingStudio::Recording.where(recordable_type: "Page").includes(:recordable, :parent_recording).order(:created_at, :id)
  end
end
