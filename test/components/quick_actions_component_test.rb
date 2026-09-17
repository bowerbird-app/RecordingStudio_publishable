# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "nokogiri"
require "devise/test/integration_helpers"
require "rails/test_help"

class QuickActionsComponentTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "QuickActionsComponentPassword!2026"

  setup do
    @user = User.find_or_create_by!(email: "quick-actions-component@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end

    sign_in @user
    @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Quick actions workspace"))
    grant_edit_access!(@root)
  end

  test "draft dropdown names the state and offers publish now" do
    recording = create_parent("Draft dropdown page")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      actor: @user,
      attributes: { slug: "draft-dropdown", status: "draft" }
    ).value!

    get "/"

    assert_response :success
    section = wrapper_html(recording)
    assert_includes section, "Draft"
    assert_includes section, "Publish now"
    assert_includes section, "Publish settings"
    assert_includes section, "inline=1"
    assert_includes section, "data-turbo-method=\"patch\""
    refute_includes section, "Back to draft"
  end

  test "published dropdown names the state and offers back to draft" do
    recording = create_parent("Published dropdown page")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      actor: @user,
      attributes: { slug: "published-dropdown", status: "published" }
    ).value!

    get "/"

    assert_response :success
    section = wrapper_html(recording)
    assert_includes section, "Published"
    assert_includes section, "check-circle"
    assert_includes section, "button-success-background-color"
    assert_includes section, "Back to draft"
    refute_includes section, "Publish now"
  end

  test "scheduled dropdown names the state and offers both verbs" do
    recording = create_parent("Scheduled dropdown page")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      actor: @user,
      attributes: {
        slug: "scheduled-dropdown",
        status: "published",
        publish_at: 2.days.from_now
      }
    ).value!

    get "/"

    assert_response :success
    section = wrapper_html(recording)

    assert_includes section, "Scheduled"
    assert_includes section, "Publish now"
    assert_includes section, "Back to draft"
  end

  private

  def wrapper_html(recording)
    wrapper = RecordingStudioPublishable::QuickActions::Component.wrapper_id(recording)
    node = Nokogiri::HTML(response.body).at_css("##{wrapper}")
    node&.to_html.to_s
  end

  def create_parent(title)
    RecordingStudio::Recording.create!(
      recordable: Page.create!(title: title),
      parent_recording: @root
    )
  end

  def grant_edit_access!(root_recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: root_recording,
      actor: @user
    )
    result.respond_to?(:value!) ? result.value! : result
  end
end
