# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"
require "rails/test_help"

class PublishedControllerTest < ActionDispatch::IntegrationTest
  test "nil layout falls through to the recording studio default layout" do
    original_gem_layout = RecordingStudioPublishable.configuration.layout
    original_core_layout = RecordingStudio.configuration.layout
    RecordingStudioPublishable.configuration.layout = nil
    RecordingStudio.configuration.layout = nil
    publishable_recording = published_page_recording("layout-default")

    get "/published/#{publishable_recording.id}/layout-default"

    assert_response :success
    assert_includes response.body, 'data-recording-studio-default-layout="true"'
  ensure
    RecordingStudioPublishable.configuration.layout = original_gem_layout
    RecordingStudio.configuration.layout = original_core_layout
  end

  test "callable layout uses the engine document layout" do
    original_layout = RecordingStudioPublishable.configuration.layout
    RecordingStudioPublishable.configuration.layout = lambda { |controller:|
      _ = controller
      "recording_studio_publishable/application"
    }
    publishable_recording = published_page_recording("layout-callable")

    get "/published/#{publishable_recording.id}/layout-callable"

    assert_response :success
    assert_includes response.body, "recording_studio-publishable-layout"
    refute_includes response.body, "flat-pack-sidebar-layout"
  ensure
    RecordingStudioPublishable.configuration.layout = original_layout
  end

  test "public layout false renders the page without a wrapping layout" do
    renderers = RecordingStudioPublishable.configuration.public_renderer_configs
    original_page = renderers["Page"]
    RecordingStudioPublishable.configuration.register_public_renderer("Page", layout: false)
    publishable_recording = published_page_recording("layout-false")

    get "/published/#{publishable_recording.id}/layout-false"

    assert_response :success
    assert_includes response.body, "Public page"
    refute_includes response.body, 'data-recording-studio-default-layout="true"'
    refute_includes response.body, "recording_studio-publishable-layout"
  ensure
    if original_page
      renderers["Page"] = original_page
    else
      renderers.delete("Page")
    end
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

  test "configured public controller action still renders the published page" do
    renderers = RecordingStudioPublishable.configuration.public_renderer_configs
    original_article = renderers["Article"]
    RecordingStudioPublishable.configuration.register_public_renderer(
      "Article",
      controller: "articles",
      action: :show,
      path: "/blogs/:uuid/:slug"
    )
    publishable_recording = published_article_recording("prepared-show")

    get "/blogs/#{publishable_recording.id}/prepared-show"

    assert_response :success
    assert_includes response.body, "Prepared Show"
  ensure
    if original_article
      renderers["Article"] = original_article
    else
      renderers.delete("Article")
    end
  end

  test "unknown public controller action is ignored and the page still renders" do
    renderers = RecordingStudioPublishable.configuration.public_renderer_configs
    original_article = renderers["Article"]
    RecordingStudioPublishable.configuration.register_public_renderer(
      "Article",
      controller: "articles",
      action: :index,
      path: "/blogs/:uuid/:slug"
    )
    publishable_recording = published_article_recording("unknown-action")

    get "/blogs/#{publishable_recording.id}/unknown-action"

    assert_response :success
    assert_includes response.body, "Parent recordable"
  ensure
    if original_article
      renderers["Article"] = original_article
    else
      renderers.delete("Article")
    end
  end

  test "a raising public controller action is swallowed and the page still renders" do
    original = ArticlesController.instance_method(:show)
    ArticlesController.define_method(:show) { raise "public controller exploded" }
    publishable_recording = published_article_recording("rescued-show")

    get "/blogs/#{publishable_recording.id}/rescued-show"

    assert_response :success
    assert_includes response.body, "Rescued Show"
  ensure
    ArticlesController.define_method(:show, original)
  end

  private

  def published_page_recording(slug)
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Public page"),
                                                          parent_recording: root)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: slug, status: "published" }
    ).value
  end

  def published_article_recording(slug)
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(
      recordable: Article.create!(title: slug.tr("-", " ").split.map(&:capitalize).join(" ")),
      parent_recording: root
    )
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: slug, status: "published" }
    ).value
  end
end
