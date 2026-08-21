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
    refute_respond_to Page, :configure_publishable!
    refute_respond_to Page, :recording_studio_publishable_path_template
    refute RecordingStudioPublishable.const_defined?(:ParentRecordable)
    refute RecordingStudio::Recording.respond_to?(:published)
    assert_respond_to Page, :indexable
    refute_respond_to Folder, :indexable
    assert_includes Array(RecordingStudio.configuration.recordable_types).map(&:to_s),
                    "RecordingStudioPublishable::Publishable"
  end

  test "dummy uses core default layout rather than a custom sidebar shell" do
    assert_includes ApplicationController.ancestors, RecordingStudio::UsesDefaultLayout
    assert_includes ApplicationController.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
    assert_equal "recording_studio/default_layout", RecordingStudioPublishable.configuration.layout

    sign_in @user
    create_publishable_parent("Layout home page")
    get root_path

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']"
    assert_select ".flat-pack-page-nav", 1
    assert_select "nav[aria-label='Page navigation']"
    assert_match "Pages", response.body
    assert_match "Sign out", response.body
    assert_select "thead"
    assert_select "td"
    refute_match "Dummy publishables", response.body
    refute_match "You are already signed in", response.body
    refute_match "flat-pack-sidebar-layout", response.body
    refute_match "recording_studio-publishable-layout", response.body
    assert_flatpack_assets_loaded
  end

  test "authenticated publishable edit uses default layout and Flatpack assets" do
    sign_in @user
    parent_recording = create_publishable_parent("Layout Checklist")

    get recording_studio_publishable.edit_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']"
    assert_select ".flat-pack-page-nav", 1
    assert_match "Sign out", response.body
    assert_match "Publish", response.body
    assert_match "Canonical URL", response.body
    assert_match "Search listing", response.body
    assert_match 'class="w-5 h-5 transition-transform duration-200"', response.body
    refute_match "flat-pack-sidebar-layout", response.body
    refute_match "recording_studio-publishable-layout", response.body
    assert_flatpack_assets_loaded
  end

  test "dummy importmap and manifest pin Flatpack CSS and JS" do
    importmap = File.read(Rails.root.join("config/importmap.rb"))
    manifest = File.read(Rails.root.join("app/assets/config/manifest.js"))
    layout = File.read(
      RecordingStudio::Engine.root.join("app/views/layouts/recording_studio/default_layout.html.erb")
    )
    controllers = File.read(Rails.root.join("app/javascript/controllers/index.js"))

    assert_includes importmap, "controllers/flat_pack"
    assert_includes importmap, "flat_pack/heroicons"
    assert_includes importmap, "preload: false"
    assert_includes controllers, 'lazyLoadControllersFrom("controllers"'
    refute_includes controllers, "eagerLoadControllersFrom"
    assert_includes manifest, "flat_pack/variables.css"
    assert_includes manifest, "flat_pack/application.css"
    assert_includes File.read(Rails.root.join("app/assets/tailwind/application.css")),
                    "tmp/tailwind/flat_pack_components"
    assert_includes layout, 'stylesheet_link_tag "tailwind"'
    assert_includes layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes layout, "javascript_importmap_tags"
  end

  test "dummy gemfile pins recording studio 4.2 and dummy-only root switchable" do
    gemfile = File.read(Rails.root.join("Gemfile"))

    assert_includes gemfile, 'tag: "v4.2.0"'
    assert_includes gemfile, 'tag: "v0.6.1"'
    assert_includes gemfile, "recording_studio_root_switchable"
    refute_includes gemfile, "recording_studio_trashable"
  end

  private

  def assert_flatpack_assets_loaded
    assert_match %r{flat_pack/variables}, response.body
    assert_match %r{stylesheet.*tailwind|tailwind-}, response.body
    assert_match "importmap", response.body
    assert_match %r{controllers/flat_pack}, response.body
  end

  def create_publishable_parent(title)
    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Layout workspace"))
    parent_recording = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: title),
      parent_recording: root
    )
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @user)
    result.respond_to?(:value!) ? result.value! : result
    parent_recording
  end
end
