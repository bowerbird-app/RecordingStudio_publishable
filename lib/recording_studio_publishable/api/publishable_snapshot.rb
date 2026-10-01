# frozen_string_literal: true

module RecordingStudioPublishable
  module Api
    module PublishableSnapshot
      STATUS_VALUES = %w[draft published scheduled].freeze
      TEXT_CONTRACT = { type: :string, required: false, allow_blank: true }.freeze
      TEXT_SCHEMA = { type: "string", nullable: true }.freeze
      TIME_CONTRACT = { type: :string, required: false, allow_blank: true }.freeze
      TIME_SCHEMA = { type: "string", format: "date-time", nullable: true }.freeze
      TEXT = { contract: TEXT_CONTRACT, schema: TEXT_SCHEMA }.freeze
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

      FIELDS = {
        status: entry(
          description: "draft, published, or scheduled. scheduled is stored as published and does not " \
                       "itself set publish_at.",
          contract: { type: :string, required: false, allow_blank: false, enum: STATUS_VALUES },
          schema: { type: "string", enum: STATUS_VALUES }
        ),
        slug: entry(contract: TEXT_CONTRACT, schema: { type: "string" }),
        publish_at: entry(
          description: "Empty string clears publish_at. When status is published, Update can then set " \
                       "publish_at to the current time.",
          contract: TIME_CONTRACT,
          schema: TIME_SCHEMA,
          time: true
        ),
        unpublish_at: entry(contract: TIME_CONTRACT, schema: TIME_SCHEMA, time: true),
        time_zone: entry(contract: TEXT_CONTRACT, schema: TEXT_SCHEMA),
        seo_title: TEXT,
        seo_description: TEXT,
        canonical_url: TEXT,
        meta_robots: TEXT,
        social_title: TEXT,
        social_description: TEXT,
        social_image_attachment_recording_id: entry(
          description: "Id of an existing image attachment recording that is a direct child of the publishable child.",
          contract: TEXT_CONTRACT,
          schema: TEXT_SCHEMA,
          identifier: true
        )
      }.freeze

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
        { publishable_recording_id: outcome.child_recording.id.to_s }.merge(column_fields(outcome.publishable))
      end

      def self.column_fields(publishable)
        FIELDS.each_with_object({}) do |(name, field), pairs|
          pairs[name] = column_value(publishable, name, field)
        end
      end

      def self.column_value(publishable, name, field)
        return api_status(publishable) if name == :status

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
      private_class_method :document_fields, :column_fields, :column_value, :field_schema_properties, :schema_for
    end
  end
end
