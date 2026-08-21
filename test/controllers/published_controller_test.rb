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
      assert_equal "application", controller.send(:publishable_layout)
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
    refute_includes response.body, "<title>Public page SEO</title>"
    assert_includes response.body, '<meta name="robots"'
    assert_includes response.body, "Rendered through the parent type&#39;s conventional public template."
    assert_includes response.body, "Page title:"
    assert_includes response.body, "Public page"
  end

  test "published page falls back to the gem template when the conventional template is missing" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    parent_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Missing template page"),
                                                          parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      attributes: { slug: "public-page", status: "published" }
    ).value

    RecordingStudioPublishable::PublishedController.any_instance.stub(:public_template, "missing/template") do
      get "/published/#{publishable_recording.id}/public-page"
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
end
