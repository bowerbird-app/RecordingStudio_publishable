# frozen_string_literal: true

require "test_helper"

# Error-type fidelity for Publishable validations (Marshal/Han 2026-10-12).
# English errors.details and messages stay byte-identical to main. String types
# from main stay String types (translated in non-English locales). Format
# validations keep their symbol type and translate via message:.
class PublishableValidationI18nTest < ActiveSupport::TestCase
  Copy = RecordingStudioPublishable::Copy

  setup do
    @previous_locale = I18n.locale
    @translations_snapshot = i18n_backend_translations_snapshot
  end

  teardown do
    I18n.locale = @previous_locale if @previous_locale
    restore_i18n_backend_translations(@translations_snapshot) if @translations_snapshot
  end

  test "english unpublish window validation details match main string type" do
    I18n.with_locale(:en) do
      publishable = RecordingStudioPublishable::Publishable.new(
        slug: "demo",
        status: :published,
        publish_at: 2.hours.from_now,
        unpublish_at: 1.hour.from_now
      )

      refute publishable.valid?
      assert_includes publishable.errors[:unpublish_at], "must be later than publish at"
      detail = publishable.errors.details[:unpublish_at].first
      assert_equal "must be later than publish at", detail[:error]
    end
  end

  test "english slug format validation keeps symbol type with translated message" do
    I18n.with_locale(:en) do
      publishable = RecordingStudioPublishable::Publishable.new(status: :draft, slug: "bad/slug")

      refute publishable.valid?
      assert_includes publishable.errors[:slug], "must use URL-safe lowercase slug segments"
      detail = publishable.errors.details[:slug].find { |entry| entry[:error] == :invalid }
      assert detail, "expected :invalid error type for format validation"
    end
  end

  test "french unpublish window full_messages use translated string type" do
    I18n.backend.store_translations(
      :fr,
      recording_studio: {
        publishable: {
          errors: {
            unpublish_after_publish: "doit être postérieur à la date de publication"
          }
        }
      }
    )

    I18n.with_locale(:fr) do
      publishable = RecordingStudioPublishable::Publishable.new(
        slug: "demo",
        status: :published,
        publish_at: 2.hours.from_now,
        unpublish_at: 1.hour.from_now
      )

      refute publishable.valid?
      assert_includes publishable.errors[:unpublish_at], "doit être postérieur à la date de publication"
      detail = publishable.errors.details[:unpublish_at].first
      assert_equal "doit être postérieur à la date de publication", detail[:error]
      assert(publishable.errors.full_messages.any? { |message| message.include?("doit être postérieur") })
    end
  end

  test "host override wins for unpublish window validation string type" do
    host_message = "HOST must be later than publish at"
    I18n.backend.store_translations(
      :en,
      recording_studio: {
        publishable: {
          errors: {
            unpublish_after_publish: host_message
          }
        }
      }
    )

    I18n.with_locale(:en) do
      publishable = RecordingStudioPublishable::Publishable.new(
        slug: "demo",
        status: :published,
        publish_at: 2.hours.from_now,
        unpublish_at: 1.hour.from_now
      )

      refute publishable.valid?
      assert_includes publishable.errors[:unpublish_at], host_message
      detail = publishable.errors.details[:unpublish_at].first
      assert_equal host_message, detail[:error]
    end
  end

  test "Copy.t english defaults cover validation keys without locale file" do
    I18n.available_locales = Array(I18n.available_locales) | [:zz]
    I18n.with_locale(:zz) do
      assert_equal(
        "must be later than publish at",
        Copy.t("errors.unpublish_after_publish")
      )
      assert_equal(
        "must use URL-safe lowercase slug segments",
        Copy.t("errors.slug_format")
      )
    end
  end

  private

  def i18n_backend_translations_snapshot
    backend = I18n.backend
    backend.send(:init_translations) unless backend.initialized?
    translations =
      if backend.respond_to?(:translations)
        backend.translations
      else
        backend.instance_variable_get(:@translations)
      end
    return unless translations

    deep_plain_copy(translations)
  end

  def restore_i18n_backend_translations(snapshot)
    backend = I18n.backend
    backend.instance_variable_set(:@translations, snapshot)
    backend.instance_variable_set(:@initialized, true) if backend.instance_variable_defined?(:@initialized)
  end

  def deep_plain_copy(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, child), copy|
        copy[key] = deep_plain_copy(child)
      end
    when Array
      value.map { |child| deep_plain_copy(child) }
    else
      value
    end
  end
end
