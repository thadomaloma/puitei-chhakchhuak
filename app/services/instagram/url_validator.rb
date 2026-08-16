module Instagram
  # Accepts only public Instagram post/reel URLs so design references can never
  # become an arbitrary-iframe or javascript:/data: injection vector.
  class UrlValidator
    ALLOWED_HOSTS = %w[instagram.com www.instagram.com instagr.am].freeze
    PATH_FORMAT = %r{\A/(?:[\w.-]+/)?(p|reel|reels|tv)/[\w-]+/?\z}

    def self.valid?(url)
      normalize(url).present?
    end

    # Returns a canonical https URL with tracking query/fragment stripped, or
    # nil when the input isn't a recognizable public Instagram post/reel link.
    def self.normalize(url)
      uri = URI.parse(url.to_s.strip)
      return nil unless uri.is_a?(URI::HTTPS)
      return nil unless ALLOWED_HOSTS.include?(uri.host&.downcase)
      return nil unless uri.path.to_s.match?(PATH_FORMAT)

      uri.query = nil
      uri.fragment = nil
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end
  end
end
