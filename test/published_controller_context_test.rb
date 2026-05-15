# frozen_string_literal: true

require "ostruct"
require "set"
require "active_support/core_ext/string/inflections"
require "action_controller/railtie"
require_relative "test_helper"
require_relative "../app/helpers/recording_studio_publishable/application_helper"
require_relative "../app/controllers/recording_studio_publishable/application_controller"
require_relative "../app/controllers/recording_studio_publishable/published_controller"

class PublishedControllerContextTest < Minitest::Test
  TestPublicController = Class.new do
    def self.action_methods
      Set.new(%w[show])
    end

    def show
      @from_public_controller = "prepared by configured action"
      @page_title_from_action = @page.title
    end

    def view_assigns
      instance_variables.each_with_object({}) do |name, assigns|
        assigns[name.to_s.delete_prefix("@")] = instance_variable_get(name)
      end
    end
  end

  def setup
    @controller = RecordingStudioPublishable::PublishedController.new
    @controller.instance_variable_set(:@page, OpenStruct.new(title: "Launch Checklist"))
    @controller.instance_variable_set(:@publishable, Object.new)
    @controller.instance_variable_set(:@recording, Object.new)
  end

  def test_prepare_public_controller_context_merges_assigns_from_configured_action
    renderer = RecordingStudioPublishable::Configuration::PublicRenderer.new(
      controller: "pages",
      action: :show,
      layout: nil
    )

    @controller.stub(:resolve_public_controller_class, TestPublicController) do
      @controller.send(:prepare_public_controller_context, renderer)
    end

    assert_equal "prepared by configured action", @controller.instance_variable_get(:@from_public_controller)
    assert_equal "Launch Checklist", @controller.instance_variable_get(:@page_title_from_action)
  end

  def test_prepare_public_controller_context_ignores_unknown_actions
    renderer = RecordingStudioPublishable::Configuration::PublicRenderer.new(
      controller: "pages",
      action: :index,
      layout: nil
    )

    @controller.stub(:resolve_public_controller_class, TestPublicController) do
      @controller.send(:prepare_public_controller_context, renderer)
    end

    assert_nil @controller.instance_variable_get(:@from_public_controller)
  end
end