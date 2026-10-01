# frozen_string_literal: true

require "recording_studio_publishable/api/perform"
require "recording_studio_publishable/api/publishable_snapshot"

module RecordingStudioPublishable
  module Api
    ACTION_VERSION = "1.0.0"
    ROUTE_KEYS = [:api_key, :api_version, "api_key", "api_version"].freeze
    ACTIONS = {
      publish: {
        http_verb: :post, summary: "Publish", description: "Publish the parent recording now.",
        success: "Recording published.", contract: :empty, service: :transition, transition: "publish"
      }.freeze,
      unpublish: {
        http_verb: :post, summary: "Unpublish", description: "Return the parent recording to draft.",
        success: "Recording unpublished.", contract: :empty, service: :transition, transition: "unpublish"
      }.freeze,
      update_publishable: {
        http_verb: :patch, summary: "Update publishable",
        description: "Update publishable columns on the child recording.",
        success: "Publishable updated.", contract: :update, service: :update
      }.freeze
    }.freeze

    def self.register_capability_action!
      Registration.register!
    end

    def self.invalid_input!(message, details:)
      if defined?(RecordingStudioApi::InvalidActionInputError)
        raise RecordingStudioApi::InvalidActionInputError.new(message, details: details)
      end

      raise StandardError, message
    end

    module Registration
      class << self
        def register!
          return unless api_available?

          contracts = Contracts.build
          each_surface { |surface_name| register_surface(surface_name, contracts) }
          nil
        end

        private

        def api_available?
          defined?(RecordingStudioApi) &&
            RecordingStudioApi.respond_to?(:capability_action) &&
            RecordingStudioApi.respond_to?(:register_capability_action) &&
            defined?(RecordingStudioApi::ActionInputContract) &&
            defined?(RecordingStudioApi::Serializers::RecordingSerializer)
        end

        def each_surface
          if named_api_registration_supported?
            RecordingStudioApi.configuration.each_api { |definition| yield definition.name }
          else
            yield nil
          end
        end

        def named_api_registration_supported?
          RecordingStudioApi.respond_to?(:configuration) &&
            RecordingStudioApi.configuration.respond_to?(:each_api) &&
            accepts_api_keyword?(:capability_action) &&
            accepts_api_keyword?(:register_capability_action)
        end

        def accepts_api_keyword?(method_name)
          RecordingStudioApi.method(method_name).parameters.any? do |type, name|
            type == :keyrest || (name == :api && %i[key keyreq].include?(type))
          end
        end

        def register_surface(surface_name, contracts)
          ACTIONS.each_key { |action_name| register_action(surface_name, action_name, contracts) }
        end

        def register_action(surface_name, action_name, contracts)
          return if existing_action(surface_name, action_name)

          register_new_action(surface_name, action_name, action_options(action_name, contracts))
        end

        def existing_action(surface_name, action_name)
          if surface_name
            RecordingStudioApi.capability_action(action_name, api: surface_name)
          else
            RecordingStudioApi.capability_action(action_name)
          end
        end

        def register_new_action(surface_name, action_name, options)
          if surface_name
            RecordingStudioApi.register_capability_action(action_name, api: surface_name, **options)
          else
            RecordingStudioApi.register_capability_action(action_name, **options)
          end
        end

        def action_options(action_name, contracts)
          spec = ACTIONS.fetch(action_name)
          action_metadata(spec).merge(
            handler: Perform::Bound.new(action_name),
            serializer: PublishableSnapshot,
            input_contract: contracts.fetch(spec.fetch(:contract)),
            openapi: Contracts.openapi_for(spec)
          )
        end

        def action_metadata(spec)
          {
            capability: :publishable,
            version: ACTION_VERSION,
            version_notes: [spec.fetch(:description)],
            http_verb: spec.fetch(:http_verb),
            scope: :member,
            required_role: :edit
          }
        end
      end
    end

    module Contracts
      class << self
        def build
          { empty: empty_contract, update: update_contract }
        end

        def openapi_for(spec)
          {
            summary: spec.fetch(:summary),
            description: spec.fetch(:description),
            responses: openapi_responses(spec)
          }
        end

        private

        def openapi_responses(spec)
          {
            "200" => success_response(spec),
            "403" => { description: "API access does not have the edit role." },
            "422" => { description: "Publishable input is invalid." }
          }
        end

        def success_response(spec)
          {
            description: spec.fetch(:success),
            content: {
              "application/json" => {
                schema: { properties: PublishableSnapshot.schema_properties }
              }
            }
          }
        end

        def empty_contract
          contract_class.new({ reject_unknown: true, fields: {} })
        end

        def update_contract
          contract_class.new({ reject_unknown: true, fields: update_fields })
        end

        def update_fields
          PublishableSnapshot::FIELDS.transform_values do |field|
            field.fetch(:contract).merge(description: field[:description]).compact
          end
        end

        def contract_class
          Class.new(RecordingStudioApi::ActionInputContract) do
            define_method(:call) do |raw_params|
              params = raw_params.respond_to?(:to_h) ? raw_params.to_h : raw_params
              params = params.except(*RecordingStudioPublishable::Api::ROUTE_KEYS) if params.respond_to?(:except)
              super(params)
            end
          end
        end
      end
    end
  end
end
