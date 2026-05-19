# frozen_string_literal: true

module RecordingStudioPublishable
  module Services
    module Publishables
      class Update < BaseService
        def initialize(parent_recording:, attributes:, actor: nil)
          @parent_recording = parent_recording
          @attributes = attributes.to_h.symbolize_keys
          @actor = actor
        end

        private

        attr_reader :parent_recording, :attributes, :actor

        def perform
          ensure_result = EnsureChild.call(parent_recording: parent_recording, actor: actor)
          return ensure_result if ensure_result.failure?

          publishable_recording = ensure_result.value
          current_publishable = publishable_recording.recordable
          validated_attributes = validated_attributes_result(publishable_recording, current_publishable)
          return validated_attributes if validated_attributes.failure?

          root_recording = publishable_recording.root_recording || parent_recording.root_recording || parent_recording

          updated_recording = root_recording.revise(
            publishable_recording,
            actor: actor,
            metadata: { source: "recording_studio_publishable.update" }
          ) do |publishable|
            assign_attributes(publishable, validated_attributes.value)
          end

          success(updated_recording)
        rescue StandardError => e
          failure(e)
        end

        def service_args
          { parent_recording_id: parent_recording&.id, attributes: attributes }
        end

        def assign_attributes(publishable, validated_attributes)
          permitted_attributes.each do |attribute|
            next unless validated_attributes.key?(attribute)
            next if attribute == :published_toggle

            publishable.public_send("#{attribute}=", validated_attributes[attribute])
          end

          publishable.slug = publishable.slug.to_s.parameterize.presence ||
                             "recording-#{parent_recording.id.to_s.first(8)}"
        end

        def permitted_attributes
          %i[
            slug status published_toggle publish_at unpublish_at time_zone seo_title seo_description canonical_url meta_robots
            social_title social_description social_image_attachment_recording_id
          ]
        end

        def validated_attributes_result(publishable_recording, current_publishable)
          validated = {}

          permitted_attributes.each do |attribute|
            next unless attributes.key?(attribute)

            normalized = normalized_value(attribute, attributes[attribute])
            return failure("#{attribute.to_s.humanize} is invalid") if normalized == :invalid

            validated[attribute] = normalized
          end

          if validated.key?(:social_image_attachment_recording_id)
            social_image_recording = validated_social_image_recording(
              validated[:social_image_attachment_recording_id],
              publishable_recording
            )
            return failure("Social image is invalid") if social_image_recording == :invalid

            validated[:social_image_attachment_recording_id] = social_image_recording&.id
          end

          apply_publish_state_side_effects(validated, current_publishable)

          success(validated)
        end

        def normalized_value(attribute, value)
          return parsed_toggle(value) if attribute == :published_toggle
          return parsed_time(value, attributes[:time_zone]) if %i[publish_at unpublish_at].include?(attribute)
          return value.presence if %i[seo_description social_description canonical_url meta_robots
                                      social_title].include?(attribute)
          return value.presence if attribute == :social_image_attachment_recording_id

          value.presence || value
        end

        def validated_social_image_recording(value, publishable_recording)
          return nil if value.blank?

          direct_image_attachments_for(publishable_recording).find_by(id: value) || :invalid
        rescue StandardError
          :invalid
        end

        def direct_image_attachments_for(publishable_recording)
          publishable_recording.recordings_query(
            include_children: true,
            type: "RecordingStudioAttachable::Attachment",
            parent_id: publishable_recording.id,
            recordable_filters: { attachment_kind: "image" }
          )
        end

        def parsed_time(value, time_zone)
          return nil if value.blank?

          zone_name = time_zone.presence || parent_recording.current_publishable&.time_zone.presence ||
                      RecordingStudioPublishable.configuration.default_time_zone
          zone = ActiveSupport::TimeZone[zone_name] || ActiveSupport::TimeZone["UTC"]
          parsed = zone.parse(value.to_s)
          parsed ? parsed.utc : :invalid
        rescue StandardError
          :invalid
        end

        def parsed_toggle(value)
          normalized = value.is_a?(Array) ? value.last : value
          ActiveModel::Type::Boolean.new.cast(normalized)
        end

        def apply_publish_state_side_effects(validated, current_publishable)
          status = status_from(validated)
          return if status.blank?

          previous_status = normalized_status(current_publishable&.status) || "draft"
          validated[:status] = status

          Rails.logger.info(
            "[RecordingStudioPublishable::Update] publish side effects start " \
            "parent_recording_id=#{parent_recording&.id} " \
            "publishable_id=#{current_publishable&.id} " \
            "previous_status=#{previous_status} target_status=#{status} " \
            "published_toggle=#{validated[:published_toggle].inspect} " \
            "publish_at_before=#{current_publishable&.publish_at&.utc&.iso8601} " \
            "unpublish_at_before=#{current_publishable&.unpublish_at&.utc&.iso8601}"
          )

          return unless validated.key?(:published_toggle)

          if status == "published"
            validated[:publish_at] = Time.current
            validated[:unpublish_at] = nil
            Rails.logger.info(
              "[RecordingStudioPublishable::Update] publish side effects applied " \
              "parent_recording_id=#{parent_recording&.id} " \
              "new_status=#{validated[:status]} " \
              "publish_at_after=#{validated[:publish_at]&.utc&.iso8601} " \
              "unpublish_at_after=#{validated[:unpublish_at]&.utc&.iso8601}"
            )
            return
          end

          validated[:unpublish_at] = Time.current if previous_status == "published"
          Rails.logger.info(
            "[RecordingStudioPublishable::Update] publish side effects applied " \
            "parent_recording_id=#{parent_recording&.id} " \
            "new_status=#{validated[:status]} " \
            "publish_at_after=#{validated[:publish_at]&.utc&.iso8601} " \
            "unpublish_at_after=#{validated[:unpublish_at]&.utc&.iso8601}"
          )
        end

        def status_from(validated)
          return "published" if validated[:published_toggle] == true
          return "draft" if validated[:published_toggle] == false

          normalized_status(validated[:status])
        end

        def normalized_status(value)
          status = value.to_s.presence
          return if status.blank?

          case status
          when "scheduled"
            "published"
          when "unpublished"
            "draft"
          else
            status
          end
        end
      end
    end
  end
end
