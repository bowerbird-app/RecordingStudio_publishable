# frozen_string_literal: true

module RecordingStudioPublishable
  module Api
    module PublishableSnapshot
      STATUS_VALUES = %w[draft published scheduled].freeze
      TEXT_CONTRACT = { type: :string, required: false, allow_blank: true }.freeze
      TEXT_SCHEMA = { type: "string", nullable: true }.freeze
      TIME_CONTRACT = { type: :string, required: false, allow_blank: true }.freeze
      TIME_SCHEMA = { type: "string", format: "date-time", nullable: true }.freeze
      PUBLIC_PATH_SCHEMA = {
        type: "string",
        nullable: true,
        description: "Public page path for this recording when it is live. Uses the nested snapshot id and slug. " \
                     "Empty unless this recording is live."
      }.freeze
      PUBLIC_URL_SCHEMA = {
        type: "string",
        nullable: true,
        description: "Absolute public page URL when this recording is live and " \
                     "Rails.application.routes.default_url_options has a host. Empty when that host is missing. " \
                     "Empty unless this recording is live."
      }.freeze
      OUTPUT_ONLY = {
        publishable_recording_id: { type: "string" }.freeze,
        public_path: PUBLIC_PATH_SCHEMA,
        public_url: PUBLIC_URL_SCHEMA
      }.freeze
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

require "recording_studio_publishable/public_read"
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

      def self.document_fields(outcome)
        read = PublicRead.for(
          outcome.parent,
          publishable: outcome.publishable,
          publishable_recording: outcome.child_recording
        )
        { publishable_recording_id: outcome.child_recording&.id&.to_s }
          .merge(column_fields(outcome.publishable, read))
          .merge(warnings_fields(outcome))
      end

      def self.warnings_fields(outcome)
        warnings = outcome.respond_to?(:warnings) ? Array(outcome.warnings) : []
        warnings = warnings.map(&:to_s).reject(&:empty?)
        return {} if warnings.empty?

        { warnings: warnings }
      end

      def self.column_fields(publishable, read)
        FIELDS.each_with_object({}) do |(name, field), pairs|
          pairs[name] = read.key?(name) ? read.fetch(name) : column_value(publishable, name, field)
        end.merge(read.slice(:public_path, :public_url))
      end

      def self.column_value(publishable, name, field)
        return if publishable.nil?

        value = publishable.public_send(name)
        return value&.iso8601 if field[:time]
        return value&.to_s if field[:identifier]

        value
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
      private_class_method :document_fields, :column_fields, :column_value, :warnings_fields
      private_class_method :field_schema_properties, :schema_for
    end
  end
end
