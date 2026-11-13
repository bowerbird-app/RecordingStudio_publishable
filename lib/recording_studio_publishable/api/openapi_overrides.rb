# frozen_string_literal: true

module RecordingStudioPublishable
  module Api
    module OpenapiOverrides
      class << self
        def write(type:, action:, title:, description:)
          key = key_for(type, action)
          if title.nil? && description.nil?
            store.delete(key)
            return
          end

          overlay = {}
          overlay[:title] = title unless title.nil?
          overlay[:description] = description unless description.nil?
          store[key] = overlay.freeze
        end

        def merge(openapi, type:, action:)
          overlay = store[key_for(type, action)]
          return openapi unless overlay

          openapi.merge(overlay)
        end

        private

        def store
          @store ||= {}
        end

        def key_for(type, action)
          [type.to_s, action.to_sym]
        end
      end
    end
  end
end
