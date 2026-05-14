user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Launch Checklist")

root_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(recordable: workspace, parent_recording_id: nil)
folder_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(root_recording_id: root_recording.id, parent_recording_id: root_recording.id, recordable: folder)
page_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(root_recording_id: root_recording.id, parent_recording_id: folder_recording.id, recordable: page)

Current.actor = user
Current.impersonator = nil
access = RecordingStudio::Access.find_or_create_by!(actor: user, role: :admin)
RecordingStudio::Recording.unscoped.find_or_create_by!(root_recording_id: root_recording.id, parent_recording_id: root_recording.id, recordable: access)

publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
  parent_recording: page_recording,
  actor: user,
  attributes: {
    slug: "launch-checklist",
    status: "published",
    seo_title: "Launch Checklist",
    seo_description: "A demo page published through the RecordingStudioPublishable addon.",
    social_title: "Launch Checklist",
    social_description: "Dummy app publishable state",
    meta_robots: "index,follow"
  }
).value!

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Page '#{page.title}' with publishable child ##{publishable_recording.id}"
