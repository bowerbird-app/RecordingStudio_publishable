# frozen_string_literal: true

module RecordingStudioPublishable
  # What a recordable returns from `publishable_http_cache` when the live
  # public page may be stored by a shared cache. `public` false, or a nil
  # return, keeps today's private response.
  class HttpCachePolicy
    def initialize(public:, max_age:, stale_while_revalidate: nil, etag: nil, vary: nil)
      @public = public
      @max_age = max_age
      @stale_while_revalidate = stale_while_revalidate
      @etag = etag
      @vary = vary
    end

    attr_reader :public, :max_age, :stale_while_revalidate, :etag, :vary

    def public?
      @public == true
    end

    def vary_header
      value = vary.to_s.strip
      value.empty? ? "Accept-Encoding" : value
    end

    def cache_control
      return unless public?

      parts = ["public", "max-age=#{max_age.to_i}"]
      parts << "stale-while-revalidate=#{stale_while_revalidate.to_i}" unless stale_while_revalidate.nil?
      parts.join(", ")
    end
  end
end
