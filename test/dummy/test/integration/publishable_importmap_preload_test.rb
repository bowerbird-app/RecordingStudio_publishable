# frozen_string_literal: true

require "test_helper"

class PublishableImportmapPreloadTest < ActiveSupport::TestCase
  CONTROLLER_PINS = %w[
    controllers/publishable_share_controller
    controllers/publishable_quick_actions_controller
  ].freeze

  test "application entry preloads publishable controllers and landing does not" do
    importmap = Rails.application.importmap

    application = preloaded_pin_names(importmap, "application")
    landing = preloaded_pin_names(importmap, "landing")
    imports = JSON.parse(
      importmap.to_json(resolver: asset_resolver, cache_key: "publishable-import-map")
    ).fetch("imports")

    CONTROLLER_PINS.each do |name|
      assert_includes application, name
      refute_includes landing, name
      assert imports.key?(name)
    end
  end

  private

  def preloaded_pin_names(importmap, entry)
    importmap.preloaded_module_packages(
      resolver: asset_resolver,
      entry_point: entry,
      cache_key: "publishable-preload-#{entry}"
    ).values.map(&:name)
  end

  def asset_resolver
    @asset_resolver ||= Class.new do
      def path_to_asset(path)
        "/assets/#{path}"
      end
    end.new
  end
end
