# frozen_string_literal: true

require "uri"

module RecordingStudioPublishable
  module ShareDestinations
    NAMES = %i[copy native linkedin x facebook email].freeze
    LINKEDIN = "https://www.linkedin.com/sharing/share-offsite/"
    X = "https://twitter.com/intent/tweet"
    FACEBOOK = "https://www.facebook.com/sharer/sharer.php"

    class << self
      def hrefs(url:, title:, destinations:)
        Array(destinations).filter_map { |name| pair(name.to_sym, url, title) }
      end

      private

      def pair(name, url, title)
        href = href_for(name, url, title)
        [name, href] if href
      end

      def href_for(name, url, title)
        case name
        when :linkedin then linkedin(url)
        when :x then tweet(url, title)
        when :facebook then facebook(url)
        when :email then email(url, title)
        end
      end

      def linkedin(url)
        "#{LINKEDIN}?#{encode(url: url)}"
      end

      def tweet(url, title)
        params = { url: url }
        text = title.to_s.strip
        params[:text] = text unless text.empty?
        "#{X}?#{encode(params)}"
      end

      def facebook(url)
        "#{FACEBOOK}?#{encode(u: url)}"
      end

      def email(url, title)
        subject = title.to_s.strip
        subject = url if subject.empty?
        body = [title.to_s.strip, url].reject { |part| part.to_s.empty? }.uniq.join("\n")
        "mailto:?#{encode(subject: subject, body: body)}"
      end

      def encode(params)
        URI.encode_www_form(params)
      end
    end
  end
end
