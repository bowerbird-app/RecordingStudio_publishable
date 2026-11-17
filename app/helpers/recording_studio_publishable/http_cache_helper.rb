# frozen_string_literal: true

module RecordingStudioPublishable
  module HttpCacheHelper
    def publishable_public_http_cache?
      policy = publishable_http_cache_policy
      policy.respond_to?(:public?) && policy.public?
    end

    def publishable_document_security_tags
      return "".html_safe if publishable_public_http_cache?

      tags = []
      tags << csrf_meta_tags if respond_to?(:csrf_meta_tags)
      tags << csp_meta_tag if respond_to?(:csp_meta_tag)
      safe_join(tags.compact, "\n")
    end

    private

    def publishable_http_cache_policy
      cached = instance_variable_get(:@publishable_http_cache) if instance_variable_defined?(:@publishable_http_cache)
      return cached if cached
      return unless respond_to?(:controller) && controller

      controller.instance_variable_get(:@publishable_http_cache)
    end
  end
end
