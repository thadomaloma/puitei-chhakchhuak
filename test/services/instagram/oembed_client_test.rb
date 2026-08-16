require "test_helper"

class Instagram::OEmbedClientTest < ActiveSupport::TestCase
  VALID_URL = "https://www.instagram.com/p/CzAbC12DeFg/"

  class FakeOEmbedClient < Instagram::OEmbedClient
    def initialize(responder:)
      super()
      @responder = responder
    end

    private

    def request(_url)
      @responder.call
    end
  end

  test "fails gracefully for a non-instagram url" do
    result = Instagram::OEmbedClient.fetch("https://example.com/not-instagram")

    assert_not result.success?
    assert_equal :invalid_url, result.error
  end

  test "fails gracefully when no access token is configured" do
    with_access_token(nil) do
      result = Instagram::OEmbedClient.fetch(VALID_URL)

      assert_not result.success?
      assert_equal :not_configured, result.error
    end
  end

  test "returns a thumbnail and author on a successful response" do
    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { { thumbnail_url: "https://example.test/thumb.jpg", author_name: "puiteichhakchhuak" }.to_json }

    with_access_token("token") do
      result = FakeOEmbedClient.new(responder: -> { response }).fetch(VALID_URL)

      assert result.success?
      assert_equal "https://example.test/thumb.jpg", result.thumbnail_url
      assert_equal "puiteichhakchhuak", result.author_name
    end
  end

  test "falls back to unavailable on a network error" do
    with_access_token("token") do
      result = FakeOEmbedClient.new(responder: -> { raise SocketError }).fetch(VALID_URL)

      assert_not result.success?
      assert_equal :unavailable, result.error
    end
  end

  test "falls back to unavailable on a non-success http response" do
    response = Net::HTTPNotFound.new("1.1", "404", "Not Found")

    with_access_token("token") do
      result = FakeOEmbedClient.new(responder: -> { response }).fetch(VALID_URL)

      assert_not result.success?
      assert_equal :http_404, result.error
    end
  end

  private

  def with_access_token(token)
    original = ENV["INSTAGRAM_OEMBED_ACCESS_TOKEN"]
    ENV["INSTAGRAM_OEMBED_ACCESS_TOKEN"] = token
    yield
  ensure
    ENV["INSTAGRAM_OEMBED_ACCESS_TOKEN"] = original
  end
end
