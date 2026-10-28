# frozen_string_literal: true

module RecordingStudio
  class RecordableTypesService
    def self.filtered_types
      Array(RecordingStudio.configuration.recordable_types).filter_map do |recordable_type|
        recordable_type if valid_recordable_type?(recordable_type)
      end
    end

    def self.valid_recordable_type?(recordable_type)
      recordable_type_name = recordable_type.to_s
      return false if recordable_type_name.blank?

      configured_types = Array(RecordingStudio.configuration.recordable_types).map do |configured_type|
        configured_type.is_a?(Class) ? configured_type.name : configured_type.to_s
      end
      return false unless configured_types.include?(recordable_type_name)

      recordable_type_name.safe_constantize.is_a?(Class)
    rescue StandardError
      false
    end
  end
end