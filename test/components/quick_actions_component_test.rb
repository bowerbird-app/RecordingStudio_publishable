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
    assert_inline_trigger(section)
    assert_includes section, "Draft"
    assert_includes section, "pencil-square"
    assert_includes section, "Publish now"
    assert_includes section, "rocket-launch"
    assert_includes section, "Schedule"
    assert_publish_form(section, recording, size: "sm")
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
    assert_inline_trigger(section)
    button = Nokogiri::HTML(section).at_css("button")
    icon = button.at_css("svg[data-flat-pack--icon-name-value='check-circle']")

    assert_includes section, "Published"
    assert_equal "default", button["data-fp-style"]
    assert_equal "solid", icon["data-flat-pack--icon-variant-value"]
    assert_equal "success", icon["data-icon-style"]
    assert_includes icon["class"], "fp-button-icon"
    refute_includes section, 'data-fp-style="success"'
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
      assert_inline_trigger(section)
      trigger_labels = Nokogiri::HTML(section).css("button span").map { |span| span.text.strip }

      assert_includes trigger_labels, "Jan 22"
      refute_includes trigger_labels, "Scheduled"
      assert_includes section, 'data-fp-style="default"'
      refute_includes section, 'data-fp-style="warning"'
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

  test "dropdown uses kit trigger_label menu_class and keep-open forms" do
    recording = draft_recording("Kit hooks page", "kit-hooks")
    html = render_quick_actions(recording, menu_class: "host-publish-menu")
    document = Nokogiri::HTML(html)
    trigger = document.at_css("[data-flat-pack--button-dropdown-target='trigger']")
    menu = document.at_css("[role='menu']")
    form = document.css("form").find { |node| node.at_css("button")&.text&.include?("Publish now") }

    refute RecordingStudioPublishable::QuickActions.const_defined?(:DropdownComponent)
    assert_includes trigger["class"], "fp-button-dropdown__trigger"
    assert trigger.at_css("[data-publishable-quick-actions-target='state']")
    assert_includes menu["class"], "publishable-quick-actions-menu"
    assert_includes menu["class"], "host-publish-menu"
    assert_equal "#{RecordingStudioPublishable::QuickActions::Component.wrapper_id(recording)}_menu", menu["id"]
    assert_equal "true", form["data-flat-pack-dropdown-keep-open"]
  end

  test "host classes attributes and state overrides merge onto the dropdown" do
    recording = draft_recording("Styled dropdown page", "styled-dropdown")

    html = render_quick_actions(
      recording,
      class: "host-publish-button",
      menu_class: "host-publish-menu",
      title: "Publish status",
      data: { publishable_host: "1" },
      states: { draft: { style: :danger, icon: "bell" } }
    )
    button = Nokogiri::HTML(html).at_css("button")
    menu = Nokogiri::HTML(html).at_css("[role='menu']")

    assert_includes button["class"], "fp-button"
    assert_includes button["class"], "inline-flex"
    assert_includes button["class"], "host-publish-button"
    assert_equal "danger", button["data-fp-style"]
    assert_equal "bell", button.at_css("svg")["data-flat-pack--icon-name-value"]
    assert_equal "Publish status", button["title"]
    assert_equal "1", button["data-publishable-host"]
    assert_includes menu["class"], "fixed"
    assert_includes menu["class"], "publishable-quick-actions-menu"
    assert_includes menu["class"], "host-publish-menu"
    assert_equal "host-publish-button", hidden_value(html, "button_class")
    assert_equal "host-publish-menu", hidden_value(html, "menu_class")
    assert hidden_value(html, "quick_actions_states").present?
  end

  test "config defaults style the dropdown and per-render values win" do
    recording = draft_recording("Config dropdown page", "config-dropdown")
    configuration = RecordingStudioPublishable.configuration
    configuration.quick_actions_button_class = "config-publish-button"
    configuration.quick_actions_menu_class = "config-publish-menu"
    configuration.quick_actions_states = { draft: { style: :warning, icon: "clock" } }

    configured = render_quick_actions(recording)
    button = Nokogiri::HTML(configured).at_css("button")
    menu = Nokogiri::HTML(configured).at_css("[role='menu']")

    assert_includes button["class"], "config-publish-button"
    assert_includes button["class"], "fp-button"
    assert_equal "warning", button["data-fp-style"]
    assert_equal "clock", button.at_css("svg")["data-flat-pack--icon-name-value"]
    assert_includes menu["class"], "config-publish-menu"

    overridden = render_quick_actions(recording, class: "host-publish-button", states: { draft: { style: :danger } })
    button = Nokogiri::HTML(overridden).at_css("button")

    assert_includes button["class"], "config-publish-button"
    assert_includes button["class"], "host-publish-button"
    assert_equal "danger", button["data-fp-style"]
    assert_equal "clock", button.at_css("svg")["data-flat-pack--icon-name-value"]
  ensure
    reset_quick_actions_style!
  end

  test "helper forwards quick action style options" do
    recording = draft_recording("Helper dropdown page", "helper-dropdown")

    html = ApplicationController.render(
      inline: "<%= render_publishable_quick_actions(@recording, class: 'from-helper', menu_class: 'helper-menu') %>",
      assigns: { recording: recording },
      layout: false
    )
    button = Nokogiri::HTML(html).at_css("button")
    menu = Nokogiri::HTML(html).at_css("[role='menu']")

    assert_includes button["class"], "from-helper"
    assert_includes button["class"], "fp-button"
    assert_includes menu["class"], "helper-menu"
  end

  test "state overrides accept icon variant and icon style" do
    recording = draft_recording("Icon style dropdown page", "icon-style-dropdown")
    configuration = RecordingStudioPublishable.configuration
    configuration.quick_actions_states = { draft: { icon_variant: :mini, icon_style: :warning } }

    configured = render_quick_actions(recording)
    icon = Nokogiri::HTML(configured).at_css("button svg[data-flat-pack--icon-name-value='pencil-square']")

    assert_equal "secondary", Nokogiri::HTML(configured).at_css("button")["data-fp-style"]
    assert_equal "mini", icon["data-flat-pack--icon-variant-value"]
    assert_equal "warning", icon["data-icon-style"]

    overridden = render_quick_actions(
      recording,
      states: { draft: { icon_variant: :solid, icon_style: :danger } }
    )
    icon = Nokogiri::HTML(overridden).at_css("button svg[data-flat-pack--icon-name-value='pencil-square']")

    assert_equal "solid", icon["data-flat-pack--icon-variant-value"]
    assert_equal "danger", icon["data-icon-style"]
  ensure
    reset_quick_actions_style!
  end

  test "flat list renders forms and keeps a separate id" do
    recording = draft_recording("List page", "list-page")

    html = ApplicationController.render(
      RecordingStudioPublishable::QuickActions::ListComponent.new(recording: recording, name: "menu"),
      layout: false
    )
    document = Nokogiri::HTML(html)
    wrapper_id = RecordingStudioPublishable::QuickActions::Component.wrapper_id(recording, name: "menu")
    wrapper = document.at_css("##{wrapper_id}")

    assert wrapper
    assert_includes wrapper["class"], "publishable-quick-actions"
    assert_list_collapse(wrapper, title: "Draft", icon: "pencil-square")
    refute wrapper.at_css("[role='presentation']")
    refute wrapper.at_css("[data-controller~='flat-pack--button-dropdown']")
    assert_publish_form(wrapper.to_html, recording, renderer: "list", name: "menu")
    assert_equal "list", hidden_value(wrapper.to_html, "quick_actions_renderer")
    assert_page_link(wrapper.to_html, recording, text: "Preview", icon: "eye", public: false)
    assert_footer_job_links(wrapper.to_html, recording)
    assert_equal 1, document.css("##{wrapper_id}").length
  end

  test "published list collapse names the state and keeps the rows" do
    recording = create_parent("Published list page")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      actor: @user,
      attributes: { slug: "published-list", status: "published" }
    ).value!

    html = ApplicationController.render(
      RecordingStudioPublishable::QuickActions::ListComponent.new(recording: recording, name: "menu"),
      layout: false
    )
    wrapper_id = RecordingStudioPublishable::QuickActions::Component.wrapper_id(recording, name: "menu")
    wrapper = Nokogiri::HTML(html).at_css("##{wrapper_id}")

    assert_list_collapse(wrapper, title: "Published", icon: "check-circle")
    assert_includes wrapper.text, "Unpublish"
    refute_includes wrapper.text, "Publish now"
    refute wrapper.at_css("[data-controller~='flat-pack--button-dropdown']")
  end

  test "list alert stays outside the collapse" do
    recording = draft_recording("List alert page", "list-alert")

    html = ApplicationController.render(
      RecordingStudioPublishable::QuickActions::ListComponent.new(
        recording: recording,
        name: "menu",
        alert: "Try again"
      ),
      layout: false
    )
    document = Nokogiri::HTML(html)
    wrapper_id = RecordingStudioPublishable::QuickActions::Component.wrapper_id(recording, name: "menu")
    wrapper = document.at_css("##{wrapper_id}")
    alert = wrapper.at_css(".publishable-quick-actions-alert")
    collapse = wrapper.at_css(".fp-menu-collapse")

    assert_includes alert.text, "Try again"
    refute collapse.at_css(".publishable-quick-actions-alert")
  end

  test "two controls for one page get different ids" do
    recording = draft_recording("Two controls page", "two-controls")
    standalone = render_quick_actions(recording, name: "standalone")
    menu = ApplicationController.render(
      RecordingStudioPublishable::QuickActions::ListComponent.new(recording: recording, name: "menu"),
      layout: false
    )
    standalone_id = RecordingStudioPublishable::QuickActions::Component.wrapper_id(recording, name: "standalone")
    menu_id = RecordingStudioPublishable::QuickActions::Component.wrapper_id(recording, name: "menu")

    refute_equal standalone_id, menu_id
    assert_includes standalone, %(id="#{standalone_id}")
    assert_includes menu, %(id="#{menu_id}")
    marker = RecordingStudioPublishable::QuickActions::Presenter.recording_class(recording)
    assert_includes standalone, marker
    assert_includes menu, marker
  end

  test "a bad control name raises" do
    recording = draft_recording("Bad name page", "bad-name")

    error = assert_raises(ArgumentError) do
      render_quick_actions(recording, name: "Page nav")
    end

    assert_includes error.message, "Page nav"
  end

  test "unknown button style raises" do
    recording = draft_recording("Bad style page", "bad-style")

    error = assert_raises(ArgumentError) do
      render_quick_actions(recording, states: { draft: { style: :neon } })
    end

    assert_includes error.message, "neon"
  end

  private

  def assert_list_collapse(wrapper, title:, icon:)
    collapse = wrapper.at_css("[data-controller~='flat-pack--menu-collapse']")
    header = collapse.at_css("button.fp-menu-collapse__button")
    panel = collapse.at_css(".fp-menu-collapse__panel")
    items = collapse.at_css(".fp-menu-collapse__items")

    assert_equal "false", collapse["data-flat-pack--menu-collapse-open-value"]
    assert_equal title, header.at_css(".fp-menu-collapse__label").text
    assert_equal icon, header.at_css(".fp-menu-collapse__icon svg")["data-flat-pack--icon-name-value"]
    assert_equal "false", header["aria-expanded"]
    assert panel["hidden"]
    assert_equal "form", items.element_children.first.name
  end

  def assert_inline_trigger(section)
    state = Nokogiri::HTML(section).at_css("[data-publishable-quick-actions-target='state']")
    classes = state["class"].to_s.split

    assert_includes classes, "inline-flex"
    assert_includes classes, "items-center"
    assert_equal %w[svg span], state.element_children.map(&:name)
    assert state.element_children.last.text.present?
  end

  def wrapper_html(recording)
    wrapper = RecordingStudioPublishable::QuickActions::Component.wrapper_id(recording)
    node = Nokogiri::HTML(response.body).at_css("##{wrapper}")
    node&.to_html.to_s
  end

  def schedule_menu_link(section, text: "Schedule")
    menu_link(section, text)
  end

  def menu_link(section, text)
    Nokogiri::HTML(section).css("a, button").find { |link| link.at_css("span")&.text == text }
  end

  def assert_publish_form(section, recording, size: nil, renderer: "dropdown", name: nil)
    form = Nokogiri::HTML(section).css("form").find { |node| node.at_css("button")&.text&.include?("Publish now") }
    assert form
    assert_equal "true", form["data-turbo-stream"]
    assert_equal "true", form["data-flat-pack-dropdown-keep-open"]
    assert_equal "post", form["method"]
    assert_equal "patch", form.at_css("input[name='_method']")["value"]
    assert_equal "1", form.at_css("input[name='inline']")["value"]
    assert_equal renderer, form.at_css("input[name='quick_actions_renderer']")["value"]
    assert_equal size, form.at_css("input[name='button_size']")["value"] if size
    if name
      assert_equal name, form.at_css("input[name='quick_actions_name']")["value"]
    else
      assert_nil form.at_css("input[name='quick_actions_name']")
    end
    assert_includes form["action"],
                    recording_studio_publishable.transition_recording_publishable_path(
                      recording_id: recording.id,
                      transition: "publish"
                    )
    refute_includes form["action"], "inline="
  end

  def hidden_value(section, name)
    Nokogiri::HTML(section).at_css("input[name='#{name}']")&.[]("value")
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

  def render_quick_actions(recording, **)
    ApplicationController.render(
      RecordingStudioPublishable::QuickActions::Component.new(recording: recording, **),
      layout: false
    )
  end

  def draft_recording(title, slug)
    recording = create_parent(title)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      actor: @user,
      attributes: { slug: slug, status: "draft" }
    ).value!
    recording
  end

  def reset_quick_actions_style!
    configuration = RecordingStudioPublishable.configuration
    configuration.quick_actions_button_class = nil
    configuration.quick_actions_menu_class = nil
    configuration.quick_actions_states = {}
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
