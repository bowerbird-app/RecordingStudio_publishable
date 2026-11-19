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
    registered = Array(RecordingStudio.configuration.recordable_types).map(&:to_s)

    assert_includes registered, "RecordingStudioPublishable::Publishable"
    assert_includes registered, "RecordingStudioAttachable::Attachment"
    refute_includes registered, "RecordingStudioAttachable::Library"
    refute_includes registered, "RecordingStudioAttachable::Placement"
    assert RecordingStudio.configuration.allow_unauthorized_writes
    refute RecordingStudio.configuration.require_actor
  end

  test "admin api recordable stays unregistered without an admin root" do
    skip unless defined?(RecordingStudioApi)

    admin_api = "RecordingStudioApi::AdminApi".constantize
    registered = Array(RecordingStudio.configuration.recordable_types).map(&:to_s)

    assert_empty Array(RecordingStudioApi.configuration.admin_root_recordable_type_names)
    refute_includes registered, admin_api.name
    refute_includes registered, "AdminRoot"
    refute RecordingStudio::RecordableDeclarations.declarations.key?(admin_api.name)
  end

  test "dummy uses core default layout rather than a custom sidebar shell" do
    assert_includes ApplicationController.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
    assert_respond_to ApplicationController, :recording_studio_layout
    assert_nil RecordingStudioPublishable.configuration.layout

    sign_in @user
    create_publishable_parent("Layout home page")
    get root_path

    assert_response :success
    assert_select "html[data-theme=rounded]"
    assert_select "body[data-recording-studio-default-layout='true']"
    assert_select ".flat-pack-page-nav", 1
    assert_select "nav[aria-label='Page navigation']"
    assert_match "Pages", response.body
    assert_match "Sign out", response.body
    assert_select "select[name=locale]", count: 1
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
    assert_select "html[data-theme=rounded]"
    assert_select "body[data-recording-studio-default-layout='true']"
    assert_select ".flat-pack-page-nav", 1
    refute_match "Sign out", response.body
    assert_select "select[name=locale]", count: 0
    refute_match "Change language", response.body
    refute_match "Studio Workspace", response.body
    assert_match "Publish", response.body
    assert_match "Preview", response.body
    assert_match "See it before it goes live.", response.body
    assert_match "Schedule", response.body
    assert_match "SEO", response.body
    assert_match "Social", response.body
    refute_match "datetime-local", response.body
    refute_match "Search engines", response.body
    refute_match "flat-pack-sidebar-layout", response.body
    refute_match "recording_studio-publishable-layout", response.body
    assert_flatpack_assets_loaded
  end

  test "dummy importmap and manifest pin Flatpack CSS and JS" do
    importmap = File.read(Rails.root.join("config/importmap.rb"))
    manifest = File.read(Rails.root.join("app/assets/config/manifest.js"))
    layout = File.read(Rails.root.join("app/views/layouts/recording_studio/default_layout.html.erb"))
    devise_layout = File.read(Rails.root.join("app/views/layouts/application.html.erb"))
    controllers = File.read(Rails.root.join("app/javascript/controllers/index.js"))

    assert_includes importmap, "controllers/flat_pack"
    refute_includes importmap, "flat_pack/heroicons"
    assert_includes importmap, "preload: false"
    assert_includes controllers, 'lazyLoadControllersFrom("controllers"'
    refute_includes controllers, "eagerLoadControllersFrom"
    assert_includes manifest, "flat_pack/variables.css"
    assert_includes manifest, "flat_pack/application.css"
    assert_includes File.read(Rails.root.join("app/assets/tailwind/application.css")),
                    "tmp/tailwind/flat_pack_components"
    assert_includes layout, "dummy_document_attributes"
    assert_includes layout, "dummy_language_selector"
    assert_includes layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes layout, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes layout, 'stylesheet_link_tag "flat_pack/rich_text"'
    assert_includes layout, 'stylesheet_link_tag "tailwind"'
    assert_includes layout, "javascript_importmap_tags"
    assert_includes devise_layout, "dummy_document_attributes"
  end

  test "public publishable pages use default layout with Flatpack rounded theme" do
    parent_recording = create_publishable_parent("Public theme page")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      actor: @user,
      attributes: {
        slug: "public-theme-page",
        status: "published",
        seo_description: "A short line for search results."
      }
    ).value!

    get parent_recording.publishable_public_path

    assert_response :success
    assert_select "html[data-theme=rounded]"
    assert_select "body[data-recording-studio-default-layout='true']"
    assert_select "meta[name=description][content='A short line for search results.']"
    assert_flatpack_assets_loaded
  end

  test "preview uses the public template without host chrome" do
    sign_in @user
    parent_recording = create_publishable_parent("Preview theme page")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: parent_recording,
      actor: @user,
      attributes: { slug: "preview-theme-page", status: "draft" }
    ).value!

    get recording_studio_publishable.preview_recording_publishable_path(recording_id: parent_recording.id)

    assert_response :success
    assert_select "html[data-theme=rounded]"
    assert_select "body[data-recording-studio-default-layout='true']"
    assert_match "Preview", response.body
    assert_match "noindex,nofollow", response.body
    refute_match "Sign out", response.body
    assert_flatpack_assets_loaded
  end

  test "dummy gemfile pins recording studio 7.3 and dummy-only root switchable" do
    gemfile = File.read(Rails.root.join("Gemfile"))
    root_gemfile = File.read(Rails.root.join("../../Gemfile"))

    assert_includes gemfile,
                    'gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"'
    assert_includes gemfile,
                    'gem "recording_studio_accessible", "~> 0.58", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.58.0"'
    assert_includes gemfile,
                    'gem "recording_studio_attachable", "~> 0.34", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.34.0"'
    assert_includes gemfile,
                    'gem "recording_studio_cache", "~> 0.8", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.8.0"'
    assert_includes gemfile,
                    'gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"'
    assert_includes gemfile,
                    'gem "recording_studio_api", "~> 1.21", github: "bowerbird-app/RecordingStudio_api", tag: "v1.21.2"'
    assert_includes gemfile,
                    'gem "recording_studio_admin", "~> 2.20", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.20.0"'
    assert_includes gemfile, <<~PIN.chomp
      gem "recording_studio_internationalization",
          github: "bowerbird-app/RecordingStudio_Internationalization", tag: "v0.3.1"
      PIN
    assert_includes gemfile,
                    'gem "recording_studio_logs", "~> 0.9", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.9.0"'
    assert_includes gemfile,
                    'gem "recording_studio_moveable", "~> 6.1", github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.1.0"'
    assert_includes gemfile,
                    'gem "recording_studio_icons", "~> 0.5", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.5.0"'
    assert_includes gemfile,
                    'gem "recording_studio_root_switchable", "~> 0.17", github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.17.0"'
    refute File.exist?(Rails.root.join("config/initializers/flatpack_removed_kwargs.rb"))
    refute File.exist?(Rails.root.join("../support/widen_recording_studio_requirement.rb"))
    refute_includes gemfile, "widen_recording_studio_requirement"
    assert_includes gemfile, <<~PIN.chomp
      gem "recording_studio_metrics", "~> 0.10", github: "bowerbird-app/RecordingStudio_metrics",
                                      tag: "v0.10.0", require: false
      PIN
    assert_includes gemfile, <<~PIN.chomp
      gem "recording_studio_trashable", "~> 1.3", github: "bowerbird-app/RecordingStudio_trashable",
                                        tag: "v1.3.0", require: false
      PIN
    assert_includes gemfile, 'gem "view_component", "~> 4.19"'
    assert File.exist?(Rails.root.join("config/recording_studio_api.yml"))
    assert_includes File.read(Rails.root.join("config/initializers/recording_studio_trashable.rb")),
                    'require "recording_studio_trashable/query"'
    assert File.exist?(
      Rails.root.join(
        "db/migrate/20261117000024_add_owner_to_recording_studio_api_api_clients.recording_studio_api.rb"
      )
    )
    assert File.exist?(
      Rails.root.join(
        "db/migrate/20261019000021_add_arrival_and_latency_bucket_to_api_request_logs.recording_studio_api.rb"
      )
    )
    %w[
      add_recording_studio_recordings_root_type_creation_index
      enforce_recording_studio_recording_root_invariant
      replace_recording_studio_recordings_root_index
    ].each do |migration_name|
      assert_empty Dir.glob(Rails.root.join("db/migrate/*#{migration_name}*").to_s)
    end
    assert_includes root_gemfile, <<~PIN.chomp
      gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "recording_studio_api", "~> 1.21", github: "bowerbird-app/RecordingStudio_api", tag: "v1.21.2",
                                             require: false
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "recording_studio_logs", "~> 0.9", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.9.0",
                                             require: false
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "recording_studio_moveable", "~> 6.1", github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.1.0",
                                                 require: false
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "recording_studio_icons", "~> 0.5", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.5.0",
                                              require: false
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "recording_studio_accessible", "~> 0.58", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.58.0"
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "recording_studio_attachable", "~> 0.34", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.34.0"
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "recording_studio_cache", "~> 0.8", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.8.0"
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "recording_studio_metrics", "~> 0.10", github: "bowerbird-app/RecordingStudio_metrics",
                                                 tag: "v0.10.0", require: false
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "recording_studio_root_switchable", "~> 0.17",
          github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.17.0"
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "recording_studio_trashable", "~> 1.3", github: "bowerbird-app/RecordingStudio_trashable",
                                                  tag: "v1.3.0", require: false
      PIN
    assert_includes root_gemfile, <<~PIN.chomp
      gem "view_component", "~> 4.19"
      PIN
    refute_includes root_gemfile, "widen_recording_studio_requirement"
    assert File.exist?(
      Rails.root.join(
        "db/migrate/20261114090000_add_root_recording_id_to_recording_studio_events.recording_studio.rb"
      )
    )
    assert_includes RecordingStudio::Event.column_names, "root_recording_id"
  end

  private

  def assert_flatpack_assets_loaded
    assert_match %r{flat_pack/variables}, response.body
    assert_match %r{flat_pack/application}, response.body
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
