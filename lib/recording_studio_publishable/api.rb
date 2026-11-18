# frozen_string_literal: true

require "recording_studio_publishable/api/openapi_overrides"
require "recording_studio_publishable/api/perform"
require "recording_studio_publishable/api/publishable_snapshot"

module RecordingStudioPublishable
  module Api
    ACTION_VERSION = "1.0.0"
    PUBLIC_PAGE_RESULT =
      "When this recording is live, public_path is the public page path, using the nested snapshot id and slug, " \
      "and public_url is the absolute URL for that path when Rails.application.routes.default_url_options has a " \
      "host. public_url is empty when that host is missing. Both are empty unless this recording is live."
    NON_INPUT_KEYS = [
      :api_key, :api_version, "api_key", "api_version",
      :member_action, "member_action"
    ].freeze
    ACTIONS = {
      publish: {
        http_verb: :post,
        summary: "Publish this recording now.",
        description:
          "Makes this recording live right away so visitors can see it. Publish settings (slug, schedule, search, " \
          "and share fields) live on a nested snapshot for this recording. Run this on the recording you want live, " \
          "not on that nested snapshot. The recording must already exist. Pass its id in the path; use the id from " \
          "list or show for this type. Send no body fields. A missing, trashed, or wrong-type id is rejected as not " \
          "found. Running this on the nested snapshot is rejected. A write the host refuses is rejected. If this " \
          "recording is already live (published, go-live time blank or already due, unpublish time blank or still " \
          "ahead), the call succeeds and leaves those times unchanged. If it is a draft, scheduled for later, or " \
          "past its unpublish time, it becomes live now, go-live is set to now, and the unpublish time is cleared. " \
          "Returns this recording with its publishable fields, including status published. #{PUBLIC_PAGE_RESULT}",
        success: "Recording published.", contract: :empty, service: :transition, transition: "publish"
      }.freeze,
      unpublish: {
        http_verb: :post,
        summary: "Return this recording to draft.",
        description:
          "Takes this recording off the live public page. Draft means it is not live. Publish settings live on a " \
          "nested snapshot for this recording. Run this on the recording you want as draft, not on that nested " \
          "snapshot. The recording must already exist. Pass its id in the path; use the id from list or show for " \
          "this type. Send no body fields. A missing, trashed, or wrong-type id is rejected as not found. Running " \
          "this on the nested snapshot is rejected. A write the host refuses is rejected. If this recording is " \
          "already draft, or has no nested snapshot yet, the call succeeds and nothing is written; no snapshot is " \
          "created. If it is live or scheduled for later, it becomes draft and both go-live and unpublish times are " \
          "cleared. Returns this recording with its publishable fields, including status draft. When there is no " \
          "nested snapshot, publishable_recording_id is empty. #{PUBLIC_PAGE_RESULT}",
        success: "Recording unpublished.", contract: :empty, service: :transition, transition: "unpublish"
      }.freeze,
      update_publishable: {
        http_verb: :patch,
        summary: "Update the publish settings on this recording.",
        description:
          "Writes slug, schedule, search, and share fields on this recording's nested publishable snapshot. Use " \
          "this to schedule a go-live, change the public slug, or edit search and share text, without using " \
          "publish or unpublish. Run this on the recording whose settings you want to change, not on that nested " \
          "snapshot. The recording must already exist. Pass its id in the path; use the id from list or show for " \
          "this type. Send only the fields you want to change. A missing, trashed, or wrong-type id is rejected as " \
          "not found. Running this on the nested snapshot is rejected. Unknown fields, an invalid slug, an invalid " \
          "date or time, an unpublish time that is not later than go-live when both are set and the record is " \
          "published, or a social image id that is not an image attachment on that nested snapshot, are rejected. " \
          "A write the host refuses is rejected. If the payload is empty or unchanged, the call still saves. When " \
          "scheduling is off for this type, publish_at, unpublish_at, and time_zone are not stored. When search " \
          "fields are off for this type, seo_title and seo_description are not stored. Returns this recording with " \
          "its publishable fields. #{PUBLIC_PAGE_RESULT}",
        success: "Publishable updated.", contract: :update, service: :update
      }.freeze
    }.freeze

    def self.register_capability_action!
      Registration.register!
    end

    def self.override_openapi(type:, action:, title: nil, description: nil)
      name = action.to_sym
      ACTIONS.fetch(name)

      OpenapiOverrides.write(type: type, action: name, title: title, description: description)
      nil
    end

    def self.openapi_for(action:, type: nil)
      name = action.to_sym
      openapi = Contracts.openapi_for(ACTIONS.fetch(name))
      return openapi if type.nil?

      OpenapiOverrides.merge(openapi, type: type, action: name)
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
          return unless named_api_registration_supported?

          RecordingStudioApi.configuration.each_api { |definition| yield definition.name }
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
          RecordingStudioApi.capability_action(action_name, api: surface_name)
        end

        def register_new_action(surface_name, action_name, options)
          RecordingStudioApi.register_capability_action(action_name, api: surface_name, **options)
        end

        def action_options(action_name, contracts)
          spec = ACTIONS.fetch(action_name)
          action_metadata(spec).merge(
            handler: Perform::Bound.new(action_name),
            serializer: PublishableSnapshot,
            input_contract: contracts.fetch(spec.fetch(:contract)),
            openapi: Contracts.openapi_for(spec),
            openapi_for: ->(type:, action:) { Api.openapi_for(action: action, type: type) }
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
      module NonInputFilter
        def call(raw_params)
          super(except_non_input_keys(raw_params))
        end

        private

        def except_non_input_keys(raw_params)
          params = raw_params.respond_to?(:to_h) ? raw_params.to_h : raw_params
          return params unless params.respond_to?(:except)

          params.except(*NON_INPUT_KEYS)
        end
      end

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
          Class.new(RecordingStudioApi::ActionInputContract) { include NonInputFilter }
        end
      end
    end
  end
end
