# frozen_string_literal: true

require "test_helper"

class QuickActionsPlacementsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "PlacementsPassword!2026"

  setup do
    @user = User.find_or_create_by!(email: "quick-actions-placements@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end
    sign_in @user
  end

  test "demo page shows the publish dropdown and the rows inside a host menu" do
    recording = placement_recording
    draft!(recording)

    get quick_actions_placements_path

    assert_response :success
    document = Nokogiri::HTML(response.body)
    ids = document.css("[id]").map { |node| node["id"] }
    assert_equal ids, ids.uniq

    standalone_id = wrapper_id(recording, "standalone")
    menu_id = wrapper_id(recording, "menu")

    assert_equal 1, document.css("##{standalone_id}").length
    assert_equal 1, document.css("##{menu_id}").length
    refute document.at_css("##{wrapper_id(recording, "page-nav")}")
    refute document.at_css("##{wrapper_id(recording, "phone")}")
    refute_includes response.body, "fp-page-nav-menu"

    standalone = document.at_css("##{standalone_id}")
    assert standalone.at_css("[data-controller~='flat-pack--button-dropdown']")
    assert_includes standalone.text, "Draft"
    assert_publish_form(standalone)
    assert_equal "dropdown", standalone.at_css("input[name='quick_actions_renderer']")["value"]
    assert_equal 1, document.css("[data-controller~='publishable-quick-actions']").length

    host_menu = document.css("[role='menu']").find { |node| node.text.include?("Rename") }
    assert host_menu
    assert_includes host_menu.text, "Duplicate"
    assert host_menu.at_css("##{menu_id}")
    refute host_menu.at_css("[data-controller~='flat-pack--button-dropdown']")

    list = document.at_css("##{menu_id}")
    collapse = list.at_css("[data-controller~='flat-pack--menu-collapse']")
    assert_equal "Draft", collapse.at_css(".fp-menu-collapse__label").text
    assert collapse.at_css(".fp-menu-collapse__panel")["hidden"]
    refute list.at_css("[data-controller~='flat-pack--button-dropdown']")
    refute standalone.at_css("[data-controller~='flat-pack--menu-collapse']")
    assert_publish_form(list)
    assert_equal "list", list.at_css("input[name='quick_actions_renderer']")["value"]

    rename = host_menu.css("button").find { |button| button.text.include?("Rename") }
    duplicate = host_menu.css("button").find { |button| button.text.include?("Duplicate") }
    assert_equal "button", rename["type"]
    assert_equal "button", duplicate["type"]

    trigger = document.css("button").find { |button| button.text.squish == "Menu" }
    assert trigger
    headings = document.css("h1, h2").map { |node| node.text.squish }
    assert_includes headings, "Where it sits"
    assert_includes headings, "Publishable button"
    assert_includes headings, "Inside a host dropdown"
  end

  test "publishing from the menu rows updates the standalone dropdown" do
    recording = placement_recording
    draft!(recording)
    selector = RecordingStudioPublishable::QuickActions::Presenter.targets_selector(recording, :state)

    patch recording_studio_publishable.transition_recording_publishable_path(
      recording_id: recording.id,
      transition: "publish",
      inline: 1,
      quick_actions_name: "menu",
      quick_actions_renderer: "list"
    ), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, %(targets="#{selector}")
    assert_includes CGI.unescapeHTML(response.body), "Published"
    assert recording.reload.current_publishable.currently_published?

    get quick_actions_placements_path

    assert_response :success
    document = Nokogiri::HTML(response.body)
    standalone = document.at_css("##{wrapper_id(recording, "standalone")}")
    menu = document.at_css("##{wrapper_id(recording, "menu")}")

    assert_includes standalone.text, "Published"
    assert_includes menu.text, "Published"
    assert standalone.at_css(selector)
    assert menu.at_css(".#{RecordingStudioPublishable::QuickActions::Presenter::TARGET_PARTS.fetch(:list)}")
  end

  private

  def placement_recording
    get quick_actions_placements_path
    assert_response :success
    recording = RecordingStudio::Recording.find_by!(recordable: Page.find_by!(title: "Placement demo"))
    ensure_edit!(recording)
    recording
  end

  def draft!(recording)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      actor: @user,
      attributes: { slug: "placement-demo", status: "draft" }
    ).value!
  end

  def ensure_edit!(recording)
    return if RecordingStudioAccessible.authorized?(actor: @user, recording: recording, role: :edit)

    admin = User.find_by!(email: "admin@admin.com")
    RecordingStudioAccessible.grant_access(
      recording: recording.root_recording,
      actor: @user,
      role: :edit,
      manager_actor: admin
    )
  end

  def wrapper_id(recording, name)
    RecordingStudioPublishable::QuickActions::Component.wrapper_id(recording, name: name)
  end

  def assert_publish_form(node)
    form = node.css("form").find { |candidate| candidate.at_css("button")&.text&.include?("Publish now") }
    assert form
    assert_equal "true", form["data-turbo-stream"]
    assert_equal "true", form["data-flat-pack-dropdown-keep-open"]
    assert_equal "patch", form.at_css("input[name='_method']")["value"]
  end
end
