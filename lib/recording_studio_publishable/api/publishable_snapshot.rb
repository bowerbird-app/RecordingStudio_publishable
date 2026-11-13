# frozen_string_literal: true

module RecordingStudioPublishable
  module Api
    module PublishableSnapshot
      STATUS_VALUES = %w[draft published scheduled].freeze
      TEXT_CONTRACT = { type: :string, required: false, allow_blank: true }.freeze
      TEXT_SCHEMA = { type: "string", nullable: true }.freeze
      TIME_CONTRACT = { type: :string, required: false, allow_blank: true }.freeze
      TIME_SCHEMA = { type: "string", format: "date-time", nullable: true }.freeze
      OUTPUT_ONLY = { publishable_recording_id: { type: "string" }.freeze }.freeze
      RECORDING_PROPERTIES = {
        id: { type: "string" }.freeze,
        type: { type: "string" }.freeze,
        parent_id: { type: "string", nullable: true }.freeze,
        root_id: { type: "string" }.freeze,
        created_at: { type: "string", format: "date-time" }.freeze,
        updated_at: { type: "string", format: "date-time" }.freeze
      }.freeze

      def self.entry(contract:, schema:, description: nil, time: false, identifier: false)
        field = { contract: contract.freeze, schema: schema.freeze }
        field[:description] = description if description
        field[:time] = true if time
        field[:identifier] = true if identifier
        field.freeze
      end
    end
  end
end

require "recording_studio_publishable/api/publishable_snapshot/fields"

module RecordingStudioPublishable
  module Api
    module PublishableSnapshot
      def self.call(outcome)
        RecordingStudioApi::Serializers::RecordingSerializer.call(outcome.parent).merge(document_fields(outcome))
      end

      def self.schema_properties
        RECORDING_PROPERTIES.merge(OUTPUT_ONLY).merge(field_schema_properties)
      end

      def self.api_status(publishable)
        return "scheduled" if publishable.scheduled_for_future?
        return "published" if publishable.published_state?

        "draft"
      end

      def self.document_fields(outcome)
        child_id = outcome.child_recording&.id&.to_s
        { publishable_recording_id: child_id }.merge(column_fields(outcome.publishable))
      end

      def self.column_fields(publishable)
        FIELDS.each_with_object({}) do |(name, field), pairs|
          pairs[name] = column_value(publishable, name, field)
        end
      end

      def self.column_value(publishable, name, field)
        return missing_column_value(name) if publishable.nil?
        return api_status(publishable) if name == :status

        value = publishable.public_send(name)
        return value&.iso8601 if field[:time]
        return value&.to_s if field[:identifier]

        value
      end

      def self.missing_column_value(name)
        name == :status ? "draft" : nil
      end

      def self.field_schema_properties
        FIELDS.transform_values do |field|
          schema_for(field)
        end
      end

      def self.schema_for(field)
        schema = field.fetch(:schema).dup
        description = field[:description]
        schema[:description] = description if description
        schema
      end
      private_class_method :entry
      private_class_method :document_fields, :column_fields, :column_value, :missing_column_value
      private_class_method :field_schema_properties, :schema_for
    end
  end
end
