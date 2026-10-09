# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < Minitest::Test
  Copy = RecordingStudioPublishable::Copy

  def setup
    ensure_gem_english_locale_available!
  end

  def teardown
    return unless defined?(@previous_load_path_for_gem_locale) && @previous_load_path_for_gem_locale

    I18n.load_path = @previous_load_path_for_gem_locale
    I18n.backend.load_translations
    @previous_load_path_for_gem_locale = nil
  end

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_rails_i18n_load_path_includes_the_gem_english_locale_file
    locale_path = File.join(engine_locales_dir, "en.yml")

    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, File.expand_path(locale_path)
  end

  def test_lib_sources_do_not_append_i18n_load_path
    lib_root = File.expand_path("../lib", __dir__)
    ruby_files = Dir[File.join(lib_root, "**", "*.rb")]

    refute_empty ruby_files, "expected lib/**/*.rb files to scan"

    ruby_files.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path", "#{path} must not touch i18n.load_path"
      refute_includes source, "I18n.load_path", "#{path} must not touch I18n.load_path"
    end
  end

  def test_dummy_french_covers_every_engine_english_key
    english = flatten_keys(locale_tree(File.join(engine_locales_dir, "en.yml"), "en"))
    french = flatten_keys(locale_tree(File.join(dummy_locales_dir, "fr.yml"), "fr"))
    missing = english - french

    assert_empty missing, "dummy fr.yml is missing keys present in engine en.yml: #{missing.join(', ')}"
  end

  def test_english_default_copy_is_unchanged
    with_gem_english_locale_only do
      I18n.with_locale(:en) do
        assert_equal "Publish", Copy.t("hub.title")
        assert_equal "Published!", Copy.t("success.title")
        assert_equal "Copy link", Copy.t("success.copy_link")
        assert_equal "Schedule", Copy.t("jobs.schedule.title")
        assert_equal "Pick when this goes live.", Copy.t("jobs.schedule.subtitle")
        assert_equal "Times saved.", Copy.t("jobs.schedule.notice")
        assert_equal "SEO", Copy.t("jobs.search.title")
        assert_equal "How this shows up in search.", Copy.t("jobs.search.subtitle")
        assert_equal "SEO saved.", Copy.t("jobs.search.notice")
        assert_equal "Social", Copy.t("jobs.social.title")
        assert_equal "Publish now", Copy.t("actions.publish_now")
        assert_equal "Change schedule", Copy.t("actions.change_schedule")
        assert_equal "Unpublish", Copy.t("actions.unpublish")
        assert_equal "Draft", Copy.t("status.draft")
        assert_equal "Published", Copy.t("status.published")
        assert_equal "Preview", Copy.t("page_link.preview")
        assert_equal "Preview", Copy.t("preview.badge")
        assert_equal "See it before it goes live.", Copy.t("page_link.preview_subtitle")
        assert_equal "See it live.", Copy.t("page_link.view_subtitle")
        assert_equal "Summary", Copy.t("summary.title")
        assert_equal "Current public metadata for this recording.", Copy.t("summary.subtitle")
        assert_equal "Slug", Copy.t("summary.slug")
        assert_equal "Canonical path", Copy.t("summary.canonical_path")
        assert_equal "Publish window", Copy.t("summary.publish_window")
        assert_equal "Always available when published", Copy.t("summary.always_available")
        assert_equal "SEO title", Copy.t("summary.seo_title")
        assert_equal "Uses parent recording title", Copy.t("summary.uses_parent_title")
        assert_equal(
          "A publishable child recording will be created the first time someone opens the edit screen.",
          Copy.t("summary.empty")
        )
        assert_equal(
          "Published from the parent recording's current recordable.",
          Copy.t("published.fallback_subtitle")
        )
        assert_equal "Parent recordable", Copy.t("published.parent_recordable")
        assert_equal "Current title", Copy.t("published.current_title")
        assert_equal "Canonical URL", Copy.t("published.canonical_url")
        assert_equal "Social card", Copy.t("published.social_card")
        assert_equal "Could not save that.", Copy.t("flashes.save_failed")
        assert_equal "Could not update this page.", Copy.t("flashes.update_failed")
        assert_equal "Social image is invalid", Copy.t("errors.social_image_invalid")
        assert_equal "must use URL-safe lowercase slug segments", Copy.t("errors.slug_format")
        assert_equal "must be later than publish at", Copy.t("errors.unpublish_after_publish")
        assert_equal "Social title", Copy.attribute_name(:social_title)
        assert_equal "Social title is invalid", Copy.attribute_invalid(:social_title)
        assert_equal(
          "Recording Studio Publishable",
          Copy.t("layout.title", default: "Recording Studio Publishable")
        )
      end
    end
  end

  def test_nested_summary_and_published_keys_resolve_without_missing_translations
    with_gem_english_locale_only do
      I18n.with_locale(:en) do
        %w[
          summary.title
          summary.empty
          published.fallback_subtitle
          published.parent_recordable
          preview.badge
          layout.title
        ].each do |key|
          full_key = "recording_studio.publishable.#{key}"
          translation = I18n.t(full_key, default: nil)

          refute_nil translation, "#{full_key} should resolve"
          assert_equal translation, I18n.t(full_key, raise: true)
        end
      end
    end
  end

  def test_component_text_overrides_win_including_nil
    assert_equal "Edit", Copy.value(Copy::UNSET, "edit_button.label")
    assert_equal "Acme edit", Copy.value("Acme edit", "edit_button.label")
    assert_nil Copy.value(nil, "edit_button.label")
  end

  def test_defaulted_follows_locale_until_the_host_changes_the_string
    I18n.with_locale(:en) do
      assert_equal "Publish", Copy.defaulted("Publish", "Publish", "hub.title")
      assert_equal "Ship it", Copy.defaulted("Ship it", "Publish", "hub.title")
      assert_equal "Publish", Copy.defaulted(nil, "Publish", "hub.title")
    end
  end

  def test_gemspec_does_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_publishable.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, "RecordingStudio_Internationalization"
  end

  def test_html_keys_escape_interpolations_and_mark_html_safe
    I18n.backend.store_translations(
      :en,
      recording_studio: { publishable: { preview: { note_html: "<strong>%{name}</strong>" } } } # rubocop:disable Style/FormatStringToken
    )
    html = Copy.t("preview.note_html", name: "<script>x</script>")

    assert_predicate html, :html_safe?
    assert_includes html, "<strong>"
    refute_includes html, "<script>"
    assert_includes html, "&lt;script&gt;x&lt;/script&gt;"
  ensure
    I18n.backend.load_translations
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def dummy_locales_dir
    File.expand_path("dummy/config/locales", __dir__)
  end

  def locale_tree(path, locale)
    yaml = YAML.safe_load_file(path, aliases: true)
    yaml.fetch(locale).fetch("recording_studio").fetch("publishable")
  end

  def flatten_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      value.is_a?(Hash) ? flatten_keys(value, path) : [path.join(".")]
    end
  end

  # Gem English assertions must ignore dummy host overrides under
  # test/dummy/config/locales. Always restore I18n.load_path.
  def with_gem_english_locale_only
    previous = I18n.load_path.dup
    I18n.load_path = [File.join(engine_locales_dir, "en.yml")]
    I18n.backend.load_translations
    yield
  ensure
    I18n.load_path = previous
    I18n.backend.load_translations
  end

  # Isolated gem suite (no dummy Rails.application) still needs the engine
  # English file available. Prefer the path Rails already registered; only
  # fall back to a one-off load for this test class, then restore.
  def ensure_gem_english_locale_available!
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    expanded = I18n.load_path.map { |path| File.expand_path(path) }
    return if expanded.include?(locale_path)

    @previous_load_path_for_gem_locale = I18n.load_path.dup
    I18n.load_path = [locale_path]
    I18n.backend.load_translations
  end
end
