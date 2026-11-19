class Article < ApplicationRecord
  recording_studio_recordable label: "Article", root: false, allowed_parent_types: ["Workspace", "Folder", "Article"]

  include RecordingStudio::Capabilities::Publishable.to(
    public_controller: "articles",
    public_action: :show,
    path: "/blogs/:uuid/:slug",
    schedule: true,
    seo: true
  )

  def publishable_description
    excerpt
  end

  def publishable_http_cache(_request)
    RecordingStudioPublishable::HttpCachePolicy.new(
      public: true,
      max_age: 300,
      stale_while_revalidate: 60,
      etag: [id, updated_at&.utc&.iso8601(6), title].join(":")
    )
  end
end
