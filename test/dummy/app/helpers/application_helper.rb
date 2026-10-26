module ApplicationHelper
  include DummyLayoutHelper
  include RecordingStudioPublishable::ApplicationHelper

  def dummy_page_nav(title:, subtitle: nil, back_url: nil, back_label: "Home", close_url: nil, close_label: "Close")
    content_for(:title, title)
    content_for(:subtitle, subtitle) if subtitle.present?

    nav = {
      round: true,
      style: :default,
      back_href: back_url,
      back_tooltip: back_label
    }
    if close_url.present?
      nav[:anchor_href] = close_url
      nav[:anchor_tooltip] = close_label
    end
    flat_pack_page_nav(**nav)
  end

  def dummy_register_host_chrome
    return if content_for?(:page_nav_right)
    return unless user_signed_in?
    return if publishable_hides_page_nav_right?

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
      concat render(
        FlatPack::Button::Component.new(
          text: "Sign out",
          style: :ghost,
          size: :md,
          href: main_app.destroy_user_session_path,
          data: { turbo_method: :delete }
        )
      )
    end
  end
end
