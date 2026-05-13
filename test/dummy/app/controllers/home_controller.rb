class HomeController < ApplicationController
  def index
    @page_recording = RecordingStudio::Recording.where(recordable_type: "Page").includes(:recordable).order(:created_at).first
    @publishable_recording = @page_recording&.publishable_child_recording
    @publishable = @publishable_recording&.recordable
  end
end
