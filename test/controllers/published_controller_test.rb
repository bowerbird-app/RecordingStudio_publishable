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

  test "published routes use the blank engine layout by default" do
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
    assert_includes response.body, "<title>Public page SEO</title>"
    assert_includes response.body, '<meta name="description" content="Search description for the public page">'
    assert_includes response.body, "Rendered through the parent type&#39;s conventional public template."
    assert_includes response.body, "Page title:"
    assert_includes response.body, "Public page"
  end

  test "published page falls back to the gem template when the conventional template is missing" do
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Public workspace"))
    folder_recording = RecordingStudio::Recording.create!(recordable: Folder.create!, parent_recording: root)
    publishable_recording = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: folder_recording,
      attributes: { slug: "folder-public", status: "published" }
    ).value

    get "/published/#{publishable_recording.id}/folder-public"

    assert_response :success
    assert_includes response.body, "Parent recordable"
    assert_includes response.body, "Folder"
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
  end
end
