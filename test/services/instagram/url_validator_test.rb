require "test_helper"

class Instagram::UrlValidatorTest < ActiveSupport::TestCase
  test "accepts a public instagram post link" do
    assert Instagram::UrlValidator.valid?("https://www.instagram.com/p/CzAbC12DeFg/")
  end

  test "accepts a reel link and strips tracking params" do
    normalized = Instagram::UrlValidator.normalize("https://instagram.com/reel/CzAbC12DeFg/?igshid=abc123")
    assert_equal "https://instagram.com/reel/CzAbC12DeFg/", normalized
  end

  test "rejects a non-instagram host" do
    assert_not Instagram::UrlValidator.valid?("https://pinterest.com/pin/12345/")
  end

  test "rejects a javascript scheme" do
    assert_not Instagram::UrlValidator.valid?("javascript:alert(1)")
  end

  test "rejects a data url" do
    assert_not Instagram::UrlValidator.valid?("data:text/html,<script>alert(1)</script>")
  end

  test "rejects an instagram profile url without a post path" do
    assert_not Instagram::UrlValidator.valid?("https://www.instagram.com/someshop/")
  end

  test "rejects malformed input" do
    assert_not Instagram::UrlValidator.valid?("not a url")
    assert_not Instagram::UrlValidator.valid?("")
    assert_not Instagram::UrlValidator.valid?(nil)
  end
end
