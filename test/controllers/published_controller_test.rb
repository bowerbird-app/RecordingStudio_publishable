# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"
require "rails/test_help"

class PublishedControllerTest < ActionDispatch::IntegrationTest
  test "publishables layout uses configured layout" do
    controller = RecordingStudioPublishable::PublishablesController.new
    config = Struct.new(:layout).new("application")

    RecordingStudioPublishable.stub(:configuration, config) do
      assert_equal "application", controller.send(:recording_studio_resolved_layout)
    end
  end

  test "nil layout falls through to recording studio then the default layout" do
    controller = RecordingStudioPublishable::PublishablesController.new
    original_gem_layout = RecordingStudioPublishable.configuration.layout
    original_core_layout = RecordingStudio.configuration.layout

    RecordingStudioPublishable.configuration.layout = nil
    RecordingStudio.configuration.layout = nil
    assert_equal "recording_studio/default_layout", controller.send(:recording_studio_resolved_layout)

    RecordingStudio.configuration.layout = "host_shell"
    assert_equal "host_shell", controller.send(:recording_studio_resolved_layout)

    RecordingStudioPublishable.configuration.layout = "admin"
    assert_equal "admin", controller.send(:recording_studio_resolved_layout)

    RecordingStudioPublishable.configuration.layout = false
    assert_equal false, controller.send(:recording_studio_resolved_layout)

    RecordingStudioPublishable.configuration.layout = ->(controller:) { "from-#{controller.class.name}" }
    assert_equal "from-RecordingStudioPublishable::PublishablesController",
                 controller.send(:recording_studio_resolved_layout)
  ensure
    RecordingStudioPublishable.configuration.layout = original_gem_layout
    RecordingStudio.configuration.layout = original_core_layout
  end

  test "public layout uses the per-type layout and falls through when that is nil" do
    controller = RecordingStudioPublishable::PublishedController.new
    renderers = RecordingStudioPublishable.configuration.public_renderer_configs
    original_page = renderers["Page"]
    original_gem_layout = RecordingStudioPublishable.configuration.layout
    original_core_layout = RecordingStudio.configuration.layout
    RecordingStudioPublishable.configuration.register_public_renderer("Page", layout: "pages")
    controller.instance_variable_set(:@parent_recording, Struct.new(:recordable_type).new("Page"))

    assert_equal "pages", controller.send(:resolve_public_layout)

    RecordingStudioPublishable.configuration.register_public_renderer("Page", layout: false)
    assert_equal false, controller.send(:resolve_public_layout)

    RecordingStudioPublishable.configuration.register_public_renderer("Page")
    RecordingStudioPublishable.configuration.layout = nil
    RecordingStudio.configuration.layout = nil
    assert_equal "recording_studio/default_layout", controller.send(:resolve_public_layout)
  ensure
    if original_page
      renderers["Page"] = original_page
    else
      renderers.delete("Page")
    end
    RecordingStudioPublishable.configuration.layout = original_gem_layout
    RecordingStudio.configuration.layout = original_core_layout
  end

  test "published routes use the blank engine layout when that layout is configured" do
    original_layout = RecordingStudioPublishable.configuration.layout
    RecordingStudioPublishable.configuration.layout = "recording_studio_publishable/application"
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Public page"),
                                                          parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: {
        slug: "public-page",
        status: "published",
        seo_title: "Public page SEO",
        seo_description: "Search description for the public page"
      }
    ).value

    get "/published/#{publishable_recording.id}/public-page"

    assert_response :success
    assert_includes response.body, "recording_studio-publishable-layout"
    refute_includes response.body, "flat-pack-sidebar-layout"
    assert_select "title", text: "Public page SEO"
  ensure
    RecordingStudioPublishable.configuration.layout = original_layout
  end

  test "published content is reachable without signing in" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Public page"),
                                                          parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "public-page", status: "published" }
    ).value

    get "/published/#{publishable_recording.id}/public-page"

    assert_response :success
    assert_includes response.body, "Public page"
  end

  test "published page shows parent recordable details" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Public page"),
                                                          parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "public-page", status: "published" }
    ).value

    get "/published/#{publishable_recording.id}/public-page"

    assert_response :success
    assert_select "title", count: 1
    assert_select "title", text: "Public page"
    assert_select "h1", text: "Public page"
    refute_includes response.body, "<title>Public page SEO</title>"
    assert_includes response.body, '<meta name="robots"'
    assert_includes response.body, "Rendered through the parent type&#39;s conventional public template."
    assert_includes response.body, "Page title:"
    assert_includes response.body, "Public page"
  end

  test "published page keeps the seo title in the document title" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Public page"),
                                                          parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: {
        slug: "public-page",
        status: "published",
        seo_title: "Public page SEO"
      }
    ).value

    get "/published/#{publishable_recording.id}/public-page"

    assert_response :success
    assert_select "title", count: 1, text: "Public page SEO"
    assert_select "h1", count: 1, text: "Public page"
  end

  test "published page falls back to the gem template when the conventional template is missing" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Missing template page"),
                                                          parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "public-page", status: "published" }
    ).value

    controller = RecordingStudioPublishable::PublishedController
    original = controller.instance_method(:public_template)
    controller.define_method(:public_template) { "missing/template" }
    begin
      get "/published/#{publishable_recording.id}/public-page"
    ensure
      controller.define_method(:public_template, original)
    end

    assert_response :success
    assert_includes response.body, "Parent recordable"
    assert_includes response.body, "Page"
  end

  test "stale slugs redirect to the canonical path" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Public page"),
                                                          parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "public-page", status: "published" }
    ).value

    get "/published/#{publishable_recording.id}/old-slug"

    assert_response :redirect
    assert_equal "/published/#{publishable_recording.id}/public-page", response.location.sub(%r{^https?://[^/]+}, "")
  end

  test "custom article public path is reachable via configured prefix" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Article.create!(title: "Blog post"),
                                                          parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "blog-post", status: "published" }
    ).value

    get "/blogs/#{publishable_recording.id}/blog-post"

    assert_response :success
    assert_includes response.body, "Blog post"
    assert_select "title", count: 1
    assert_select "title", text: "Blog post"
    assert_includes response.body, '<meta name="robots" content="index,follow">'
    assert_includes response.body, '<link rel="canonical"'
  end

  test "published noindex page emits robots and is not indexable" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    page = Page.create!(title: "Hidden page")
    parent_recording = RecordingStudio::Recording.create!(recordable: page, parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "hidden-page", status: "published", meta_robots: "noindex,follow" }
    ).value

    get "/published/#{publishable_recording.id}/hidden-page"

    assert_response :success
    assert_includes response.body, '<meta name="robots" content="noindex,follow">'
    refute page.reload.indexable?
  end

  test "draft public pages are not found" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Draft page"),
                                                          parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "draft-page", status: "draft" }
    ).value

    get "/published/#{publishable_recording.id}/draft-page"

    assert_response :not_found
  end

  test "scheduled public pages are not found" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Scheduled page"),
                                                          parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: {
        slug: "scheduled-page",
        status: "published",
        publish_at: 2.days.from_now,
        time_zone: "UTC"
      }
    ).value

    get "/published/#{publishable_recording.id}/scheduled-page"

    assert_response :not_found
  end
end
