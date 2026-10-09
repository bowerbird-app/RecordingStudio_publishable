# frozen_string_literal: true

require "test_helper"

class CustomerI18nTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "Password"

  setup do
    @user = User.find_or_create_by!(email: "i18n-admin@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end

    sign_in @user
    @root = RecordingStudio::Recording.create!(recordable: Workspace.create!(name: "I18n Workspace"))
    grant_edit_access!(@root)
    @recording = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: "Launch Checklist"),
      parent_recording: @root
    )
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: @recording,
      actor: @user,
      attributes: { slug: "launch-checklist", status: "draft" }
    ).value!
  end

  test "language selector sits in the dummy nav left of the workspace switcher" do
    get "/"

    assert_response :success
    assert_select "form[action='/recording_studio_internationalization/locale']"
    assert_includes response.body, "English"
    assert_includes response.body, "Français"
    assert_select "html[lang='en']"
    assert_select "html[data-theme=rounded]"

    language_at = response.body.index("dummy-language-selector")
    switcher_at = response.body.index("recording-studio-root-switchable--root-switch-dropdown")
    assert language_at, "expected a language selector in the nav"
    assert switcher_at, "expected a workspace switcher in the nav"
    assert language_at < switcher_at, "language selector should sit left of the workspace switcher"
  end

  test "publish flow stays English by default" do
    get recording_studio_publishable.edit_recording_publishable_path(recording_id: @recording.id)

    assert_response :success
    assert_select "html[lang='en']"
    assert_includes response.body, "Publish"
    assert_includes response.body, "Preview"
    assert_includes response.body, "See it before it goes live."
    assert_includes response.body, "Schedule"
    assert_includes response.body, "Pick when this goes live."
    assert_includes response.body, "SEO"
    assert_includes response.body, "Social"
    assert_includes response.body, "Launch Checklist"
    assert_includes response.body, "Publish now"

    get recording_studio_publishable.schedule_recording_publishable_path(recording_id: @recording.id)

    assert_response :success
    assert_includes response.body, "Publish at"
    assert_includes response.body, "Time zone"
    assert_includes response.body, "Save"

    get recording_studio_publishable.search_recording_publishable_path(recording_id: @recording.id)

    assert_response :success
    assert_includes response.body, "Leave blank to use the page name."
    assert_includes response.body, "Canonical URL"
    assert_includes response.body, "Advanced"

    get recording_studio_publishable.social_recording_publishable_path(recording_id: @recording.id)

    assert_response :success
    assert_includes response.body, "Social title"
    assert_includes response.body, "Upload Photo"
  end

  test "dummy French locale renders publish flow copy" do
    switch_to_french

    get recording_studio_publishable.edit_recording_publishable_path(recording_id: @recording.id)

    assert_response :success
    assert_select "html[lang='fr']"
    assert_includes response.body, "Publier"
    assert_includes response.body, "Aperçu"
    assert_includes response.body, "Voir avant la mise en ligne."
    assert_includes response.body, "Horaires"
    assert_includes response.body, "Choisissez quand ça passe en ligne."
    assert_includes response.body, "Publier maintenant"
    refute_includes response.body, "See it before it goes live."
    refute_includes response.body, "Pick when this goes live."
    assert_includes response.body, "Launch Checklist"

    get recording_studio_publishable.schedule_recording_publishable_path(recording_id: @recording.id)

    assert_response :success
    assert_includes response.body, "Publier le"
    assert_includes response.body, "Fuseau horaire"
    assert_includes response.body, "Enregistrer"
    refute_includes response.body, "Time zone"

    get recording_studio_publishable.search_recording_publishable_path(recording_id: @recording.id)

    assert_response :success
    assert_includes response.body, "Laissez vide pour utiliser le nom de la page."
    assert_includes response.body, "URL canonique"
    assert_includes response.body, "Avancé"
    refute_includes response.body, "Canonical URL"

    get recording_studio_publishable.social_recording_publishable_path(recording_id: @recording.id)

    assert_response :success
    assert_includes response.body, "Titre social"
    assert_includes response.body, "Envoyer une photo"
    refute_includes response.body, "Upload Photo"
  end

  test "edit button label override still wins over French locale" do
    recording = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: "No publishable yet"),
      parent_recording: @root
    )

    I18n.with_locale(:fr) do
      default_html = ApplicationController.render(
        RecordingStudioPublishable::EditButtonComponent.new(recording: recording),
        layout: false
      )
      override_html = ApplicationController.render(
        RecordingStudioPublishable::EditButtonComponent.new(recording: recording, label: "Host label"),
        layout: false
      )

      assert_includes default_html, "Modifier"
      refute_includes default_html, "Host label"
      assert_includes override_html, "Host label"
      refute_includes override_html, "Modifier"
    end
  end

  test "host config/locales English override wins on a real preview page" do
    override_path = Rails.root.join("config/locales/publishable_host_override.en.yml")
    original = File.read(override_path)

    assert_path_exists override_path, "expected host override file in test/dummy/config/locales/"
    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, override_path.to_s

    File.write(override_path, <<~YAML)
      en:
        recording_studio:
          publishable:
            preview:
              badge: Host preview
    YAML
    I18n.reload!

    assert_equal "Host preview", I18n.t("recording_studio.publishable.preview.badge")

    get recording_studio_publishable.preview_recording_publishable_path(recording_id: @recording.id)

    assert_response :success
    assert_includes response.body, "Host preview"
    refute_includes response.body, ">Preview<"
    assert_includes response.body, "Launch Checklist"
  ensure
    File.write(override_path, original) if override_path && original
    I18n.reload!
  end

  test "summary card empty state renders gem English copy" do
    recording = RecordingStudio::Recording.create!(
      recordable: Page.create!(title: "No publishable yet"),
      parent_recording: @root
    )

    html = ApplicationController.render(
      partial: "recording_studio_publishable/components/summary_card",
      locals: { recording: recording }
    )

    assert_includes html, "Summary"
    assert_includes html, "Current public metadata for this recording."
    assert_includes html,
                    "A publishable child recording will be created the first time someone opens the edit screen."
  end

  private

  def switch_to_french
    patch "/recording_studio_internationalization/locale", params: { locale: "fr", return_to: "/" }
    follow_redirect!
  end

  def grant_edit_access!(root_recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: root_recording,
      actor: @user
    )
    result.respond_to?(:value!) ? result.value! : result
  end
end
