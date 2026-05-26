class HomeController < ApplicationController
  before_action :load_edit_button_component

  def index
    @publishable_parent_recordings = publishable_parent_recordings
  end

  private

  def publishable_parent_recordings
    RecordingStudio::Recording.where(recordable_type: %w[Page Article Widget]).includes(:recordable, :parent_recording).order(:created_at, :id)
  end

  def load_edit_button_component
    require_dependency RecordingStudioPublishable::Engine.root.join("app/components/recording_studio_publishable/edit_button_component").to_s
  end
end
