# frozen_string_literal: true

require "test_helper"

class PublishableDummyEnablementTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "DummyEnablementPassword!2026"

  setup do
    @user = User.find_or_create_by!(email: "dummy-enablement@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end
  end

  test "dummy boots with publishable enabled on page and article only" do
    page_source = File.read(Rails.root.join("app/models/page.rb"))
    article_source = File.read(Rails.root.join("app/models/article.rb"))
    folder_source = File.read(Rails.root.join("app/models/folder.rb"))

    assert_includes page_source, "include RecordingStudio::Capabilities::Publishable.to"
    assert_includes article_source, "include RecordingStudio::Capabilities::Publishable.to"
    refute_includes folder_source, "Publishable.to"

    assert RecordingStudio.capability_enabled?(:publishable, for: Page)
    assert RecordingStudio.capability_enabled?(:publishable, for: Article)
    refute RecordingStudio.capability_enabled?(:publishable, for: Folder)
    refute RecordingStudio.capability_enabled?(:publishable, for: Workspace)
    assert_respond_to Page, :published
    refute_respond_to Folder, :published
    refute_respond_to Page, :recording_studio_publishable
    refute RecordingStudio::Recording.respond_to?(:published)
    assert_respond_to Page, :indexable
    refute_respond_to Folder, :indexable
    assert_includes Array(RecordingStudio.configuration.recordable_types).map(&:to_s),
                    "RecordingStudioPublishable::Publishable"
  end

  test "dummy uses core default layout rather than a custom sidebar shell" do
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout

    sign_in @user
    get root_path

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']"
    refute_match "flat-pack-sidebar-layout", response.body
    assert_match "Dummy publishables", response.body
  end

  test "dummy gemfile pins recording studio 4.2" do
    gemfile = File.read(Rails.root.join("Gemfile"))

    assert_includes gemfile, 'tag: "v4.2.0"'
    assert_includes gemfile, 'tag: "v0.6.1"'
    refute_includes gemfile, "recording_studio_trashable"
  end
end
