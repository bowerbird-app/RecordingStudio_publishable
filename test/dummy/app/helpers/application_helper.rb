module ApplicationHelper
  include RecordingStudioPublishable::ApplicationHelper

  def dummy_page_nav(title:, back_url: nil, back_label: "Home", close_url: nil, close_label: "Close")
    recording_studio_page_nav(
      title: title,
      page_nav_back_url: back_url,
      page_nav_back_label: back_label,
      page_nav_anchor_url: close_url,
      page_nav_anchor_label: close_label
    )
  end
end
