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

  test "demo page places the dropdown on the page and in the bar, and the flat list in a menu and the phone menu" do
    get quick_actions_placements_path

    assert_response :success
    recording = RecordingStudio::Recording.find_by!(recordable: Page.find_by!(title: "Placement demo"))
    document = Nokogiri::HTML(response.body)
    ids = document.css("[id]").map { |node| node["id"] }

    assert_equal ids, ids.uniq

    standalone_id = wrapper_id(recording, "standalone")
    page_nav_id = wrapper_id(recording, "page-nav")
    menu_id = wrapper_id(recording, "menu")
    phone_id = wrapper_id(recording, "phone")

    [standalone_id, page_nav_id, menu_id, phone_id].each do |id|
      assert_equal 1, document.css("##{id}").length, id
    end

    standalone = document.at_css("##{standalone_id}")
    refute ancestor_match?(standalone, ".fp-page-nav")
    refute ancestor_match?(standalone, "[data-controller~='flat-pack--top-nav']")
    assert standalone.at_css("[data-controller~='flat-pack--button-dropdown']")
    assert_publish_form(standalone)

    top_nav = document.at_css("[data-controller~='flat-pack--top-nav']")
    bar = top_nav.at_css("[data-flat-pack-top-nav-section='right']")
    assert_equal "false", bar["data-flat-pack-top-nav-collapsible"]
    assert bar.at_css("##{page_nav_id} [data-flat-pack--button-dropdown-target='trigger']")
    refute top_nav["style"].to_s.include?("height")

    list = document.at_css("##{menu_id}")
    assert ancestor_match?(list, "[role='menu']")
    refute list.at_css("[data-controller~='flat-pack--button-dropdown']")
    assert_publish_form(list)
    assert_equal "list", list.at_css("input[name='quick_actions_renderer']")["value"]

    phone = document.at_css("##{phone_id}")
    assert ancestor_match?(phone, ".fp-page-nav-menu")
    assert ancestor_match?(phone, "[data-controller~='flat-pack--top-nav']")
    refute ancestor_match?(phone, "[data-flat-pack-top-nav-section='right']")
    refute phone.at_css("[data-controller~='flat-pack--button-dropdown']")
    assert_publish_form(phone)
    assert_equal "list", phone.at_css("input[name='quick_actions_renderer']")["value"]

    left = top_nav.at_css("[data-flat-pack-top-nav-section='left']")
    assert_equal "", left.text.squish
    assert_equal "Where it sits", document.at_css("h1").text.squish
  end

  private

  def ancestor_match?(node, selector)
    node.ancestors.any? { |ancestor| ancestor.element? && ancestor.matches?(selector) }
  end

  def wrapper_id(recording, name)
    RecordingStudioPublishable::QuickActions::Component.wrapper_id(recording, name: name)
  end

  def assert_publish_form(node)
    form = node.css("form").find { |candidate| candidate.at_css("button")&.text&.include?("Publish now") }
    assert form
    assert_equal "true", form["data-turbo-stream"]
    assert_equal "patch", form.at_css("input[name='_method']")["value"]
  end
end
