# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordable
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")

# Create/find the root recording using the current API.
root_recording = RecordingStudio.root_recording_for(workspace)

folder_recording = root_recording.recording_for(folder)
folder_recording ||= root_recording.record(folder, actor: user, parent_recording: root_recording)

root_recording.recording_for(page) || root_recording.record(page, actor: user, parent_recording: folder_recording)

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
