# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"
require "rails/test_help"

class PublishableShareButtonTest < ActiveSupport::TestCase
  setup do
    @previous_share_button = RecordingStudioPublishable.configuration.share_button
    @previous_url_options = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options = {}
    @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Share workspace"))
  end

  teardown do
    RecordingStudioPublishable.configuration.share_button = @previous_share_button
    Rails.application.routes.default_url_options = @previous_url_options
  end

  test "renders the absolute public url for a live recording and not the current page" do
    recording = publish_page("Live share", slug: "live-share")
    html, request = render_share(recording, path: "/embeds/#{recording.id}")
    copied = clipboard_text(html)
    public_url = "http://press.example#{recording.reload.publishable_public_path}"

    assert recording.currently_published?
    assert_equal public_url, copied
    refute_includes copied, "/embeds/"
    refute_equal request.original_url, copied
    assert_includes html, 'aria-label="Share"'
    assert_includes html, "arrow-up-tray"
    assert_includes html, 'data-fp-style="secondary"'
    assert_includes html, 'role="tooltip"'
    assert_includes html, ">Share<"
  end

  test "uses the configured host when the request has no base url" do
    Rails.application.routes.default_url_options = { host: "public.test", protocol: "https" }
    recording = publish_page("Hosted share", slug: "hosted-share")
    forget_public_url(recording)

    html, = render_share(recording, base: :none)
    copied = clipboard_text(html)

    assert_equal recording.reload.publishable_public_path, copied
    assert_match %r{\Ahttps://public\.test/}, copied
    refute_includes copied, "press.example"
  end

  test "keeps an absolute public url when the current request is an embed on another host" do
    Rails.application.routes.default_url_options = { host: "public.test", protocol: "https" }
    recording = publish_page("Canonical share", slug: "canonical-share")
    forget_public_url(recording)

    html, request = render_share(recording, host: "press.example", path: "/embeds/#{recording.id}")

    assert_includes request.original_url, "/embeds/"
    assert_equal recording.reload.publishable_public_path, clipboard_text(html)
    assert_match %r{\Ahttps://public\.test/}, clipboard_text(html)
    refute_includes clipboard_text(html), "press.example"
    refute_includes clipboard_text(html), "/embeds/"
  end

  test "renders nothing for a draft even when a public path exists" do
    recording = publish_page("Draft share", slug: "draft-share", status: "draft")

    assert_empty share_html(recording)
  end

  test "renders nothing for a future publish_at" do
    recording = publish_page("Future share", slug: "future-share", status: "published", publish_at: 1.hour.from_now)

    refute recording.currently_published?
    assert_empty share_html(recording)
  end

  test "renders nothing for an expired unpublish_at" do
    recording = publish_page(
      "Expired share",
      slug: "expired-share",
      status: "published",
      publish_at: 2.hours.ago,
      unpublish_at: 1.hour.ago
    )

    refute recording.currently_published?
    assert_empty share_html(recording)
  end

  test "publish_at equal to now renders and unpublish_at equal to now does not" do
    freeze_time do
      now = Time.current.change(usec: 0)
      travel_to now
      recording = publish_page("Boundary share", slug: "boundary-share", status: "published", publish_at: now)

      assert recording.reload.currently_published?
      assert_equal now.to_i, recording.current_publishable.publish_at.to_i
      assert_predicate clipboard_text(share_html(recording)), :present?

      publish_page_on(recording, slug: "boundary-share", status: "published", publish_at: 1.hour.ago, unpublish_at: now)
      recording.reload

      refute recording.currently_published?
      assert_equal now.to_i, recording.current_publishable.unpublish_at.to_i
      assert_empty share_html(recording)
    end
  end

  test "renders nothing for a trashed publishable child" do
    recording = publish_page("Trashed share", slug: "trashed-share")
    child = recording.publishable_child_recording
    RecordingStudio::Recording.where(id: child.id).update_all(trashed_at: Time.current)
    recording.reload

    refute recording.currently_published?
    assert_empty share_html(recording)
  end

  test "renders nothing for a recording that is not publishable" do
    refute @root.currently_published?
    assert_empty share_html(@root)
  end

  test "per-call overrides beat config and config beats the built-in look" do
    recording = publish_page("Styled share", slug: "styled-share")
    default_html = share_html(recording)

    assert_includes default_html, 'data-fp-style="secondary"'
    assert_includes default_html, "arrow-up-tray"
    assert_includes default_html, 'aria-label="Share"'

    RecordingStudioPublishable.configuration.share_button = {
      style: :primary,
      icon: "link",
      icon_only: false,
      label: "Send"
    }
    configured = share_html(recording)

    assert_includes configured, 'data-fp-style="primary"'
    assert_includes configured, 'data-flat-pack--icon-name-value="link"'
    assert_includes configured, ">Send<"
    refute_includes configured, 'role="tooltip"'

    overridden = share_html(
      recording,
      style: :danger,
      icon: "paper-airplane",
      icon_only: true,
      label: "Pass it on",
      class: "share-custom"
    )

    assert_includes overridden, 'data-fp-style="danger"'
    assert_includes overridden, 'data-flat-pack--icon-name-value="paper-airplane"'
    assert_includes overridden, 'aria-label="Pass it on"'
    assert_includes overridden, "share-custom"
    refute_includes overridden, ">Send<"
  end

  test "variant is an alias for style and text is an alias for the label" do
    recording = publish_page("Alias share", slug: "alias-share")
    html = share_html(recording, variant: :danger, text: "Hand off", icon_only: false)

    assert_includes html, 'data-fp-style="danger"'
    assert_includes html, ">Hand off<"
    assert_equal "http://press.example#{recording.publishable_public_path}", clipboard_text(html)
  end

  test "uses the translated share label" do
    recording = publish_page("French share", slug: "french-share")

    I18n.with_locale(:fr) do
      html = share_html(recording)

      assert_includes html, 'aria-label="Partager"'
      assert_includes html, ">Partager<"
    end
  end

  private

  def publish_page(title, **attributes)
    attributes = { status: "published" }.merge(attributes)
    recording = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: title),
      parent_recording: @root
    )
    publish_page_on(recording, **attributes)
    recording.reload
  end

  def publish_page_on(recording, **attributes)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: attributes
    ).value!
  end

  def share_html(recording, **)
    html, = render_share(recording, **)
    html
  end

  def render_share(recording, host: "press.example", path: "/embeds/kit", base: :request, **overrides)
    expose_path_unless_live(recording)
    controller = ActionController::Base.new
    request = nil
    if base == :request
      request = ActionDispatch::TestRequest.create(
        "HTTP_HOST" => host,
        "PATH_INFO" => path,
        "REQUEST_METHOD" => "GET",
        "rack.url_scheme" => "http",
        "SERVER_PORT" => "80"
      )
      controller.request = request
      controller.response = ActionDispatch::TestResponse.new
    end
    view = controller.view_context
    view.extend(RecordingStudioPublishable::ShareHelper)
    [view.publishable_share_button(recording, **overrides).to_s, request]
  end

  def forget_public_url(recording)
    recordable = recording.recordable
    return unless recordable.instance_variable_defined?(:@published_url)

    recordable.remove_instance_variable(:@published_url)
  end

  def expose_path_unless_live(recording)
    return if recording.currently_published?

    recording.recordable.define_singleton_method(:published_url) { "/forced/#{recording.id}" }
  end

  def clipboard_text(html)
    html.to_s[/data-flat-pack--clipboard-text-value="([^"]*)"/, 1].to_s
  end
end
