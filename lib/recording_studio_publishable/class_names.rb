# frozen_string_literal: true

module RecordingStudioPublishable
  module ClassNames
    module_function

    def merge(*parts)
      names = parts.flatten.compact.flat_map { |part| part.to_s.split(/\s+/) }.reject(&:empty?)
      return "" if names.empty?
      return names.join(" ") unless defined?(TailwindMerge::Merger)

      TailwindMerge::Merger.new.merge(names.join(" "))
    end
  end
end
