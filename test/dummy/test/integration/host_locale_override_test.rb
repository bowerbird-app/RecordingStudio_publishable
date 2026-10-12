# frozen_string_literal: true

require "test_helper"

class HostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_UNKNOWN = "HOST Unknown publishable transition"
  OVERRIDE_KEY = "recording_studio.publishable.errors.unknown_transition"
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_publishable_host.en.yml")
  TEST_PASSWORD = "Password"

  setup do
    @load_path_before = I18n.load_path.dup
    @user = User.find_or_create_by!(email: "host-override-admin@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end
    sign_in @user
    @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Host Override Workspace"))
    grant_edit_access!(@root)
    @recording = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: "Host Override Page"),
      parent_recording: @root
    )
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: @recording,
      actor: @user,
      attributes: { slug: "host-override-page", status: "draft" }
    ).value!
  end

  teardown do
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order host override test must not mutate I18n.load_path"
  end

  # Real-boot-order guard: host file under config/locales must win without any
  # test-time load_path mutation. Render assertion uses the unknown-transition flash.
  test "boot-loaded host locale override wins on unknown transition flash" do
    assert_path_exists BOOT_HOST_LOCALE
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_UNKNOWN
    assert_equal HOST_UNKNOWN, I18n.t(OVERRIDE_KEY)
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    patch recording_studio_publishable.transition_recording_publishable_path(
      recording_id: @recording.id,
      transition: "not-a-real-transition"
    )

    assert_response :redirect
    assert_equal HOST_UNKNOWN, flash[:alert]
    follow_redirect!
    assert_includes response.body, HOST_UNKNOWN
  end

  private

  def grant_edit_access!(root_recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: root_recording,
      actor: @user
    )
    result.respond_to?(:value!) ? result.value! : result
  end
end
