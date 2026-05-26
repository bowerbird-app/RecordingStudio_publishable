user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Launch Checklist")
article = Article.find_or_create_by!(title: "Spring Release Notes") do |record|
  record.excerpt = "A second publishable recordable type routed through ArticlesController#show."
end
widget = Widget.find_or_create_by!(title: "Homepage Hero") do |record|
  record.summary = "A placement-only recordable type that publishes without a standalone URL."
end

root_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(recordable: workspace, parent_recording_id: nil)
folder_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(root_recording_id: root_recording.id, parent_recording_id: root_recording.id, recordable: folder)
page_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(root_recording_id: root_recording.id, parent_recording_id: folder_recording.id, recordable: page)
article_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(root_recording_id: root_recording.id, parent_recording_id: folder_recording.id, recordable: article)
widget_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(root_recording_id: root_recording.id, parent_recording_id: folder_recording.id, recordable: widget)

Current.actor = RecordingStudio::ActorResolver.resolve_actor.call(user)
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

article_publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
  parent_recording: article_recording,
  actor: user,
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

widget_publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
  parent_recording: widget_recording,
  actor: user,
  attributes: {
    status: "published",
    publish_at: 2.days.from_now.iso8601,
    social_title: "Homepage Hero",
    social_description: "A scheduled placement-only widget with no standalone URL."
  }
).value!

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Page '#{page.title}' with publishable child ##{publishable_recording.id}"
puts "Seeded: Article '#{article.title}' with publishable child ##{article_publishable_recording.id}"
puts "Seeded: Widget '#{widget.title}' with publishable child ##{widget_publishable_recording.id}"
