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
          validated_attributes = validated_attributes_result(publishable_recording)
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

            publishable.public_send("#{attribute}=", validated_attributes[attribute])
          end

          publishable.slug = publishable.slug.to_s.parameterize.presence ||
                             "recording-#{parent_recording.id.to_s.first(8)}"
        end

        def permitted_attributes
          attributes = %i[
            slug status social_title social_description social_image_attachment_recording_id
          ]

          if schedule_enabled_for_recordable?
            attributes.concat(%i[publish_at unpublish_at time_zone])
          end

          if seo_enabled_for_recordable?
            attributes.concat(%i[seo_title seo_description canonical_url meta_robots])
          end

          attributes
        end

        def schedule_enabled_for_recordable?
          RecordingStudioPublishable.configuration.schedule_enabled_for(parent_recording.recordable_type)
        end

        def seo_enabled_for_recordable?
          RecordingStudioPublishable.configuration.seo_enabled_for(parent_recording.recordable_type)
        end

        def validated_attributes_result(publishable_recording)
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

          apply_publish_state_side_effects(validated)

          Rails.logger.warn(
            "[PublishableDebug] validated attributes parent_recording_id=#{parent_recording.id} raw_status=#{attributes[:status].inspect} normalized_status=#{validated[:status].inspect} publish_at=#{validated[:publish_at].inspect} unpublish_at=#{validated[:unpublish_at].inspect} time_zone=#{validated[:time_zone].inspect}"
          )

          success(validated)
        end

        def normalized_value(attribute, value)
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

        def apply_publish_state_side_effects(validated)
          status = status_from(validated)
          Rails.logger.warn(
            "[PublishableDebug] side effects input status=#{validated[:status].inspect} resolved_status=#{status.inspect} publish_at=#{validated[:publish_at].inspect} unpublish_at=#{validated[:unpublish_at].inspect}"
          )
          return if status.blank?

          validated[:status] = status

          if status == "published"
            validated[:unpublish_at] = nil
            validated[:publish_at] = Time.current if validated[:publish_at].blank?
            return
          end

          validated[:publish_at] = nil
          validated[:unpublish_at] = nil

          Rails.logger.warn(
            "[PublishableDebug] side effects output status=#{validated[:status].inspect} publish_at=#{validated[:publish_at].inspect} unpublish_at=#{validated[:unpublish_at].inspect}"
          )
        end

        # Normalize UI/API status input to the two persisted enum values.
        # We treat "scheduled" as "published" with a future publish_at.
        def status_from(validated)
          raw = validated[:status].to_s.strip.downcase

          return "draft" if raw == "draft"
          return "published" if raw == "published" || raw == "scheduled"

          nil
        end
      end
    end
  end
end
