# frozen_string_literal: true

class QuickActionsPlacementsController < ApplicationController
  layout "quick_actions_placements"

  def show
    @recording = placement_recording
  end

  private

  def placement_recording
    page = Page.find_by(title: "Placement demo")
    recording = page && RecordingStudio::Recording.find_by(recordable: page)
    return recording if recording.present?

    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Placements"))
    RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: current_user)
    created = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: "Placement demo"),
      parent_recording: root
    )
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: created,
      actor: current_user,
      attributes: { slug: "placement-demo", status: "draft" }
    )
    created
  end
end
