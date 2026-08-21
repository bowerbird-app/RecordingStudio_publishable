admin_user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

viewer_user = User.find_or_create_by!(email: "viewer@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Launch Checklist")
article = Article.find_or_create_by!(title: "Spring Release Notes") do |record|
  record.excerpt = "A second publishable recordable type routed through ArticlesController#show."
end

root_recording = RecordingStudio.root_recording_for(workspace)

folder_recording = root_recording.recording_for(folder)
folder_recording ||= root_recording.record(folder, actor: admin_user, parent_recording: root_recording)

page_recording = root_recording.recording_for(page)
page_recording ||= root_recording.record(page, actor: admin_user, parent_recording: folder_recording)

article_recording = root_recording.recording_for(article)
article_recording ||= root_recording.record(article, actor: admin_user, parent_recording: folder_recording)

Current.actor = RecordingStudio::ActorResolver.resolve_actor.call(admin_user)
Current.impersonator = nil

if defined?(RecordingStudioAccessible)
  RecordingStudioAccessible.bootstrap_owner_access!(recording: root_recording, actor: admin_user)
  RecordingStudioAccessible.grant_access(
    recording: root_recording,
    actor: viewer_user,
    role: :view,
    manager_actor: admin_user
  )
end

publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
  parent_recording: page_recording,
  actor: admin_user,
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

article_publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
  parent_recording: article_recording,
  actor: admin_user,
  attributes: {
    slug: "spring-release-notes",
    status: "published",
    seo_title: "Spring Release Notes",
    seo_description: "A demo article published through the ArticlesController mapping.",
    social_title: "Spring Release Notes",
    social_description: "Dummy app article publishable state",
    meta_robots: "index,follow"
  }
).value!

puts "Seeded: admin@admin.com / Password"
puts "Seeded: viewer@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Page '#{page.title}' with publishable child ##{publishable_recording.id}"
puts "Seeded: Article '#{article.title}' with publishable child ##{article_publishable_recording.id}"
