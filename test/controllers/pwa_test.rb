require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "manifest describes an installable standalone application" do
    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = response.parsed_body
    assert_equal "Puitei", manifest.fetch("short_name")
    assert_equal "Puitei Chhakchhuak — Tailoring Shop Management", manifest.fetch("name")
    assert_equal "standalone", manifest.fetch("display")
    assert_equal "#00142a", manifest.fetch("theme_color")
    assert manifest.fetch("icons").any? { |icon| icon["sizes"] == "192x192" }
    assert manifest.fetch("icons").any? { |icon| icon["src"] == "/icon-maskable.png" && icon["purpose"] == "maskable" }
  end

  test "offline page is available without authentication" do
    get offline_path

    assert_response :success
    assert_select "h1", "You're offline"
    assert_select "img.mark[src='/puitei-mark.svg'][alt='Puitei Chhakchhuak']"
  end

  test "service worker includes offline navigation fallback" do
    get pwa_service_worker_path

    assert_response :success
    assert_includes response.body, "caches.match(\"/offline\")"
    assert_includes response.body, "/icon-maskable.png"
  end

  test "application shell exposes the Puitei Chhakchhuak identity without SaaS signup" do
    get new_user_session_path

    assert_response :success
    assert_select "meta[name='theme-color'][content='#00142a']"
    assert_select "link[rel='icon'][href='/puitei-mark.svg?v=1'][type='image/svg+xml']"
    assert_select "link[rel='icon'][href='/favicon-32.png?v=4'][sizes='32x32']"
    assert_select "link[rel='icon'][href='/icon.png']", count: 0
    assert_select "link[rel='apple-touch-icon'][href='/apple-touch-icon.png?v=4']"
    assert_select "img.auth-brand-logo[src='/puitei-mark.svg'][width='512'][height='512']"
    assert_select "body", text: /Puitei Chhakchhuak/
    assert_select "body", text: /free trial|sign up/i, count: 0
  end
end
