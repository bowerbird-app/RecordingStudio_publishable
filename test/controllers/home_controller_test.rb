# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "devise/test/integration_helpers"
require "rails/test_help"

class HomeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "HomeTestPassword!2026"

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end

    root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "Home workspace"))
    @page_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Home page"),
                                                         parent_recording: root)
    @second_page_recording = RecordingStudio::Recording.create!(recordable: Page.create!(title: "Second page"),
                                                                parent_recording: root)

    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: @page_recording,
      actor: @user,
      attributes: { slug: "home-page", status: "published" }
    ).value!

    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @user)
    result.respond_to?(:value!) ? result.value! : result

    sign_in @user
  end

  test "home page renders a page index table" do
    get "/"

    assert_response :success
    assert_includes response.body, '<html data-theme="rounded">'
    assert_includes response.body, "Pages"
    assert_includes response.body, "Add page"
    assert_includes response.body, "Sign out"
    assert_includes response.body, "Home page"
    assert_includes response.body, "Second page"
    assert_includes response.body, "<thead"
    assert_includes response.body, "<td"
    refute_includes response.body, "Dummy publishables"
    refute_includes response.body, "You are already signed in"
    assert_includes response.body,
                    recording_studio_publishable.edit_recording_publishable_path(recording_id: @page_recording.id)
  end

  test "add page page renders and creates a new page recording" do
    expected_title = "Dummy Page #{Page.count + 1}"

    get new_dummy_page_path

    assert_response :success
    assert_includes response.body, "Create page"
    assert_includes response.body, 'name="title"'
    assert_includes response.body, expected_title
    assert_includes response.body.force_encoding("UTF-8"), expected_title

    assert_difference -> { Page.count }, 1 do
      assert_difference -> { RecordingStudio::Recording.where(recordable_type: "Page").count }, 1 do
        post dummy_pages_path, params: { title: "Custom Page Name" }
      end
    end

    assert_redirected_to root_path
  end

  test "add page creates a new page recording" do
    assert_difference -> { Page.count }, 1 do
      assert_difference -> { RecordingStudio::Recording.where(recordable_type: "Page").count }, 1 do
        post dummy_pages_path
      end
    end

    assert_redirected_to root_path
    follow_redirect!

    assert_response :success
    assert_includes response.body, "Dummy Page"
  end

  test "edit page renders for a publishable recording" do
    get recording_studio_publishable.edit_recording_publishable_path(recording_id: @page_recording.id)

    assert_response :success
    assert_includes response.body, "Publish"
    assert_includes response.body, 'type="datetime-local" name="publishable[publish_at]"'
    assert_includes response.body, 'type="datetime-local" name="publishable[unpublish_at]"'
    refute_includes response.body, "SEO title"
    refute_includes response.body, "SEO description"
    assert_includes response.body, "Select social image"
  end

  test "edit page accepts a publishable child recording id without nesting another publishable" do
    publishable_recording = @page_recording.publishable_child_recording

    assert_no_difference lambda {
      RecordingStudio::Recording.where(parent_recording_id: publishable_recording.id,
                                       recordable_type: RecordingStudioPublishable::Publishable.name).count
    } do
      get recording_studio_publishable.edit_recording_publishable_path(recording_id: publishable_recording.id)
    end

    assert_response :success
    assert_includes response.body, "Publish"
    assert_includes response.body, recording_studio_publishable.publishable_path(recording_id: @page_recording.id)
  end
end
