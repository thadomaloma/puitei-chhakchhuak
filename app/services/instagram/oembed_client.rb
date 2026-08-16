module Instagram
  # Thin wrapper around Meta's official Instagram oEmbed endpoint. Only ever
  # returns a thumbnail/author summary for a public post/reel URL -- never
  # renders Instagram's raw embed HTML, so there is nothing to sanitize or
  # mark html_safe. Any failure (missing credentials, network error, private
  # or deleted post) degrades to a plain "open on Instagram" link upstream;
  # it never raises into the caller.
  class OEmbedClient
    ENDPOINT = "https://graph.facebook.com/v21.0/instagram_oembed".freeze
    OPEN_TIMEOUT = 3
    READ_TIMEOUT = 4

    Result = Struct.new(:success?, :thumbnail_url, :author_name, :error, keyword_init: true)

    def self.fetch(url)
      new.fetch(url)
    end

    def fetch(url)
      normalized_url = Instagram::UrlValidator.normalize(url)
      return failure(:invalid_url) unless normalized_url
      return failure(:not_configured) unless access_token.present?

      response = request(normalized_url)
      return failure(:"http_#{response.code}") unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      Result.new(success?: true, thumbnail_url: data["thumbnail_url"], author_name: data["author_name"], error: nil)
    rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError, EOFError => e
      Rails.logger.warn("Instagram oEmbed request failed: #{e.class}: #{e.message}")
      failure(:unavailable)
    end

    private

    def request(url)
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(url: url, access_token: access_token, omitscript: true)

      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get(uri.request_uri)
      end
    end

    def access_token
      Rails.application.credentials.dig(:instagram, :oembed_access_token).presence || ENV["INSTAGRAM_OEMBED_ACCESS_TOKEN"]
    end

    def failure(reason)
      Result.new(success?: false, error: reason)
    end
  end
end
