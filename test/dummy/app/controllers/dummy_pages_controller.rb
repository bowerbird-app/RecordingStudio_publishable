# frozen_string_literal: true

class DummyPagesController < ApplicationController
  def new
    @next_page_title = next_page_title
  end

  def create
    page = Page.create!(title: page_title_param.presence || next_page_title)
    RecordingStudio::Recording.create!(recordable: page, parent_recording: workspace_root_recording)

    redirect_to root_path, notice: "Added #{page.title}"
  end

  private

  def workspace_root_recording
    RecordingStudio::Recording.where(recordable_type: "Workspace", parent_recording_id: nil).includes(:recordable).order(:created_at, :id).first ||
      RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Dummy Workspace"))
  end

  def next_page_title
    "Dummy Page #{Page.count + 1}"
  end

  def page_title_param
    params.fetch(:title, "").to_s.strip
  end
end