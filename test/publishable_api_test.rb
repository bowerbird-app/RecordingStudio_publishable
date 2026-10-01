# frozen_string_literal: true

require "test_helper"

class PublishableApiTest < Minitest::Test
  SUMMARIES = {
    publish: "Publish",
    unpublish: "Unpublish",
    update_publishable: "Update publishable"
  }.freeze
  DESCRIPTIONS = {
    publish: "Publish the parent recording now.",
    unpublish: "Return the parent recording to draft.",
    update_publishable: "Update publishable columns on the child recording."
  }.freeze
  SUCCESS_DESCRIPTIONS = {
    publish: "Recording published.",
    unpublish: "Recording unpublished.",
    update_publishable: "Publishable updated."
  }.freeze

  def test_registration_is_nil_when_recording_studio_api_is_undefined
    refute Object.const_defined?(:RecordingStudioApi, false)

    assert_nil RecordingStudioPublishable::Api.register_capability_action!
  end

  def test_registration_is_nil_without_the_input_contract
    api = Module.new
    serializers = Module.new
    serializers.const_set(:RecordingSerializer, Class.new)
    api.const_set(:Serializers, serializers)
    api.define_singleton_method(:capability_action) { |*| nil }
    api.define_singleton_method(:register_capability_action) { |*| raise "registered an action" }
    Object.const_set(:RecordingStudioApi, api)

    assert_nil RecordingStudioPublishable::Api.register_capability_action!
  ensure
    remove_recording_studio_api!
  end

  def test_registration_registers_the_three_publishable_actions
    with_fake_recording_studio_api do |api|
      RecordingStudioPublishable::Api.register_capability_action!

      assert_equal(%i[publish unpublish update_publishable], api.registrations.map { |row| row.fetch(:name) })
      assert_registered_action(api, :publish, :post)
      assert_registered_action(api, :unpublish, :post)
      assert_registered_action(api, :update_publishable, :patch)
      api.registrations.each { |row| refute row.key?(:api) }
    end
  end

  def test_second_registration_does_not_add_another_row
    with_fake_recording_studio_api do |api|
      RecordingStudioPublishable::Api.register_capability_action!
      RecordingStudioPublishable::Api.register_capability_action!

      assert_equal 3, api.registrations.size
    end
  end

  def test_registration_registers_each_named_api
    with_fake_recording_studio_api(api_names: %w[public operations partners]) do |api|
      RecordingStudioPublishable::Api.register_capability_action!

      assert_equal(
        %w[public operations partners].product(%i[publish unpublish update_publishable]),
        registered_pairs(api)
      )
    end
  end

  def test_existing_action_on_one_api_does_not_block_other_apis
    existing = { ["public", :publish] => Object.new }
    with_fake_recording_studio_api(api_names: %w[public operations partners], existing_actions: existing) do |api|
      RecordingStudioPublishable::Api.register_capability_action!

      assert_equal(
        [
          ["public", :unpublish],
          ["public", :update_publishable],
          ["operations", :publish],
          ["operations", :unpublish],
          ["operations", :update_publishable],
          ["partners", :publish],
          ["partners", :unpublish],
          ["partners", :update_publishable]
        ],
        registered_pairs(api)
      )
    end
  end

  def test_contract_strips_route_keys_and_rejects_an_unknown_key
    with_fake_recording_studio_api do |api|
      RecordingStudioPublishable::Api.register_capability_action!
      contract = registration(api, :update_publishable).fetch(:input_contract)
      stripped = contract.call(
        "slug" => "launch",
        "api_key" => "public",
        api_version: "v1",
        member_action: { "slug" => "launch" }
      )
      unknown = contract.call(slug: "launch", api_key: "public", "api_version" => "v1", extra: true)

      assert_operator contract.class, :<, RecordingStudioApi::ActionInputContract
      assert_equal({ slug: "launch" }, stripped.value)
      assert_equal ["Unknown parameters: extra"], unknown.errors
    end
  end

  def test_publish_contract_rejects_status
    with_fake_recording_studio_api do |api|
      RecordingStudioPublishable::Api.register_capability_action!
      publish_contract = registration(api, :publish).fetch(:input_contract)
      result = publish_contract.call(status: "published")

      assert_same publish_contract, registration(api, :unpublish).fetch(:input_contract)
      assert_equal ["Unknown parameters: status"], result.errors
    end
  end

  def test_update_contract_accepts_slug_and_scheduled_status
    with_fake_recording_studio_api do |api|
      RecordingStudioPublishable::Api.register_capability_action!
      contract = registration(api, :update_publishable).fetch(:input_contract)
      accepted = contract.call(slug: "launch", status: "scheduled", api_key: "public", "api_version" => "v1")
      blank = contract.call(status: "")
      unknown = contract.call(slug: "launch", extra: "no")

      assert_equal [], accepted.errors
      assert_equal({ slug: "launch", status: "scheduled" }, accepted.value)
      assert_equal ["status must be one of: draft, published, scheduled"], blank.errors
      assert_equal ["Unknown parameters: extra"], unknown.errors
    end
  end

  def test_invalid_input_raises_the_api_error_when_that_class_exists
    with_fake_recording_studio_api do
      error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
        RecordingStudioPublishable::Api.invalid_input!("Social image is invalid", details: ["Social image is invalid"])
      end

      assert_equal "Social image is invalid", error.message
      assert_equal ["Social image is invalid"], error.details
    end
  end

  def test_invalid_input_raises_standard_error_without_the_api_error_class
    error = assert_raises(StandardError) do
      RecordingStudioPublishable::Api.invalid_input!("Social image is invalid", details: ["Social image is invalid"])
    end

    assert_instance_of StandardError, error
    assert_equal "Social image is invalid", error.message
  end

  def test_engine_registers_api_actions_before_the_api_initializer
    initializer = RecordingStudioPublishable::Engine.initializers.find do |candidate|
      candidate.name == "recording_studio_publishable.register_recording_studio_api_action"
    end

    assert_equal "recording_studio_api.after_initialize", initializer.before
  end

  private

  def assert_registered_action(api, name, verb)
    row = registration(api, name)
    openapi = row.fetch(:openapi)
    schema = openapi.dig(:responses, "200", :content, "application/json", :schema)
    properties = schema.fetch(:properties)

    assert_equal :publishable, row.fetch(:capability)
    assert_equal "1.0.0", row.fetch(:version)
    assert_equal verb, row.fetch(:http_verb)
    assert_equal :member, row.fetch(:scope)
    assert_equal :edit, row.fetch(:required_role)
    assert_instance_of RecordingStudioPublishable::Api::Perform::Bound, row.fetch(:handler)
    assert_equal name, row.fetch(:handler).action_name
    assert_equal RecordingStudioPublishable::Api::PublishableSnapshot, row.fetch(:serializer)
    refute openapi.key?(:tags)
    assert_equal SUMMARIES.fetch(name), openapi.fetch(:summary)
    assert_equal DESCRIPTIONS.fetch(name), openapi.fetch(:description)
    assert_equal SUCCESS_DESCRIPTIONS.fetch(name), openapi.dig(:responses, "200", :description)
    assert_equal "API access does not have the edit role.", openapi.dig(:responses, "403", :description)
    assert_equal "Publishable input is invalid.", openapi.dig(:responses, "422", :description)
    refute schema.key?(:$ref)
    %i[
      id type parent_id root_id created_at updated_at
      publishable_recording_id status slug seo_title social_title publish_at
    ].each do |key|
      assert properties.key?(key), "OpenAPI 200 schema is missing #{key}"
    end
    assert_equal "string", properties.dig(:id, :type)
    assert_equal "date-time", properties.dig(:created_at, :format)
    assert_equal true, properties.dig(:parent_id, :nullable)
    assert_equal({ type: "string" }, properties.fetch(:publishable_recording_id))
    assert_equal %w[draft published scheduled], properties.dig(:status, :enum)
    assert_equal(
      "draft, published, or scheduled. scheduled is stored as published and does not itself set publish_at.",
      properties.dig(:status, :description)
    )
  end

  def registration(api, name)
    api.registrations.find { |row| row.fetch(:name) == name }
  end

  def registered_pairs(api)
    api.registrations.map { |row| [row.fetch(:api), row.fetch(:name)] }
  end

  def with_fake_recording_studio_api(api_names: nil, existing_actions: {})
    api = Module.new
    serializers = Module.new
    serializers.const_set(:RecordingSerializer, Class.new)
    api.const_set(:Serializers, serializers)
    api.const_set(:ActionInputContract, fake_action_input_contract_class)
    api.const_set(:UnsupportedActionError, Class.new(StandardError))
    api.const_set(:InvalidActionInputError, invalid_action_input_error_class)
    registrations = []
    if api_names
      install_named_api(api, registrations, existing_actions, api_names)
    else
      install_public_api(api, registrations, existing_actions)
    end
    api.define_singleton_method(:registrations) { registrations }
    Object.const_set(:RecordingStudioApi, api)
    yield api
  ensure
    remove_recording_studio_api!
  end

  def install_public_api(api, registrations, existing_actions)
    api.define_singleton_method(:capability_action) do |name|
      existing_actions[name] || registrations.find { |row| row.fetch(:name) == name }
    end
    api.define_singleton_method(:register_capability_action) do |name, **options|
      registrations << options.merge(name: name)
    end
  end

  def install_named_api(api, registrations, existing_actions, api_names)
    normalized = existing_actions.each_with_object({}) do |(key, value), output|
      api_name, action_name = key
      output[[api_name.to_s, action_name]] = value
    end
    configuration = fake_api_configuration(api_names)
    api.define_singleton_method(:configuration) { configuration }
    api.define_singleton_method(:capability_action) do |name, api: :public|
      key = [api.to_s, name]
      normalized[key] || registrations.find { |row| row[:api] == api.to_s && row[:name] == name }
    end
    api.define_singleton_method(:register_capability_action) do |name, api: :public, **options|
      registrations << options.merge(name: name, api: api.to_s)
    end
  end

  def fake_api_configuration(api_names)
    definitions = api_names.map { |name| Struct.new(:name).new(name.to_s) }
    Struct.new(:definitions) do
      def each_api(&)
        definitions.each(&)
      end
    end.new(definitions)
  end

  def fake_action_input_contract_class
    result_class = Struct.new(:success?, :value, :errors, keyword_init: true)
    evaluator = method(:evaluate_contract)
    Class.new do
      define_method(:initialize) do |definition|
        normalized = definition.to_h.deep_symbolize_keys
        @fields = normalized.fetch(:fields)
        @reject_unknown = normalized.fetch(:reject_unknown, true)
      end

      define_method(:call) do |raw_params|
        evaluator.call(@fields, @reject_unknown, raw_params, result_class)
      end
    end
  end

  def evaluate_contract(fields, reject_unknown, raw_params, result_class)
    params = raw_params.to_h.deep_symbolize_keys
    errors = []
    unknown_keys = params.keys - fields.keys
    errors << "Unknown parameters: #{unknown_keys.sort.join(', ')}" if reject_unknown && unknown_keys.any?
    output = {}
    fields.each { |field_name, rules| append_field_value(params, field_name, rules, output, errors) }
    result_class.new(success?: errors.empty?, value: errors.empty? ? output : nil, errors: errors)
  end

  def append_field_value(params, field_name, rules, output, errors)
    return unless params.key?(field_name)

    value = rules[:type].to_sym == :string ? params[field_name].to_s : params[field_name]
    if rules[:enum] && !Array(rules[:enum]).include?(value)
      errors << "#{field_name} must be one of: #{Array(rules[:enum]).join(', ')}"
      return
    end
    if rules.fetch(:allow_blank, true) == false && value.blank?
      errors << "#{field_name} cannot be blank"
      return
    end

    output[field_name] = value
  end

  def invalid_action_input_error_class
    Class.new(StandardError) do
      attr_reader :details

      def initialize(message = nil, details: [])
        super(message)
        @details = details
      end
    end
  end

  def remove_recording_studio_api!
    Object.send(:remove_const, :RecordingStudioApi) if Object.const_defined?(:RecordingStudioApi, false)
  end
end
