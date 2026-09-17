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

  test "draft dropdown names the state and offers publish now and schedule" do
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
    assert_includes section, "pencil-square"
    assert_includes section, "Publish now"
    assert_includes section, "rocket-launch"
    assert_includes section, "Schedule"
    assert_includes section, "inline=1"
    assert_includes section, "button_size=sm"
    assert_includes section, "data-turbo-method=\"patch\""
    refute_includes section, "Back to draft"
    refute_includes section, "Unpublish"

    schedule_link = schedule_menu_link(section)
    assert schedule_link
    assert_includes schedule_link["href"],
                    recording_studio_publishable.schedule_recording_publishable_path(recording_id: recording.id)
    refute_includes schedule_link["href"], "schedule="
    assert_nil schedule_link["data-turbo-method"]

    assert_page_link(section, recording, text: "Preview", icon: "eye", public: false)
    assert_footer_job_links(section, recording)
  end

  test "draft dropdown omits schedule when scheduling is off" do
    recording = create_parent("Draft no schedule page")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      actor: @user,
      attributes: { slug: "draft-no-schedule", status: "draft" }
    ).value!

    RecordingStudioPublishable.configuration.stub :schedule_enabled_for, false do
      get "/"

      assert_response :success
      section = wrapper_html(recording)
      assert_includes section, "Publish now"
      assert_nil schedule_menu_link(section)
      assert_footer_job_links(section, recording)
    end
  end

  test "published dropdown names the state and offers unpublish" do
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
    assert_includes section, "Unpublish"
    refute_includes section, "Back to draft"
    refute_includes section, "Publish now"
    assert schedule_menu_link(section)
    assert_page_link(section, recording, text: "View", icon: "arrow-top-right-on-square", public: true)
    assert_footer_job_links(section, recording)
  end

  test "scheduled dropdown shows the date and offers change schedule" do
    recording = create_parent("Scheduled dropdown page")
    publish_at = Time.utc(2026, 1, 22, 15, 0, 0)

    travel_to Time.utc(2026, 1, 10, 12, 0, 0) do
      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: recording,
        actor: @user,
        attributes: {
          slug: "scheduled-dropdown",
          status: "published",
          publish_at: publish_at,
          time_zone: "UTC"
        }
      ).value!

      get "/"

      assert_response :success
      section = wrapper_html(recording)
      trigger_labels = Nokogiri::HTML(section).css("button span").map { |span| span.text.strip }

      assert_includes trigger_labels, "Jan 22"
      refute_includes trigger_labels, "Scheduled"
      assert_includes section, "button-default-background-color"
      refute_includes section, "button-warning-background-color"
      assert_includes section, "Publish now"
      assert_includes section, "rocket-launch"
      assert_includes section, "Unpublish"
      refute_includes section, "Back to draft"
      assert_nil schedule_menu_link(section)
      assert schedule_menu_link(section, text: "Change schedule")
      assert_page_link(section, recording, text: "Preview", icon: "eye", public: false)
      refute_includes section, ">View<"
      assert_footer_job_links(section, recording)
    end
  end

  private

  def wrapper_html(recording)
    wrapper = RecordingStudioPublishable::QuickActions::Component.wrapper_id(recording)
    node = Nokogiri::HTML(response.body).at_css("##{wrapper}")
    node&.to_html.to_s
  end

  def schedule_menu_link(section, text: "Schedule")
    menu_link(section, text)
  end

  def menu_link(section, text)
    Nokogiri::HTML(section).css("a").find { |link| link.at_css("span")&.text == text }
  end

  def assert_page_link(section, recording, text:, icon:, public:)
    link = menu_link(section, text)
    assert link
    assert_includes section, icon
    assert_equal "_blank", link["target"]
    assert_includes link["rel"].to_s, "noopener"
    assert_equal "false", link["data-turbo"]

    if public
      child = recording.publishable_child_recording
      assert child
      assert_includes link["href"], child.id.to_s
      refute_includes link["href"], "preview"
    else
      assert_includes link["href"],
                      recording_studio_publishable.preview_recording_publishable_path(recording_id: recording.id)
      refute_includes link["href"], "preview="
    end
  end

  def assert_footer_job_links(section, recording)
    refute_includes section, "Publish settings"
    assert Nokogiri::HTML(section).at_css('[role="separator"]')

    seo = menu_link(section, "SEO")
    social = menu_link(section, "Social")
    assert seo
    assert social
    assert_includes seo["href"],
                    recording_studio_publishable.search_recording_publishable_path(recording_id: recording.id)
    assert_includes social["href"],
                    recording_studio_publishable.social_recording_publishable_path(recording_id: recording.id)
    assert_nil seo["data-turbo-method"]
    assert_nil social["data-turbo-method"]
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
