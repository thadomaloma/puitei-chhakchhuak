require "test_helper"

class PhaseFifteenReadinessTest < ActionDispatch::IntegrationTest
  test "readiness probe verifies database connectivity without authentication" do
    get readiness_check_path

    assert_response :success
    assert_equal({ "status" => "ready" }, response.parsed_body)
  end

  test "authenticated shell exposes security and accessibility foundations" do
    sign_in users(:owner)

    get root_path

    assert_response :success
    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_includes response.headers["Permissions-Policy"], "camera=()"
    assert_includes response.headers["Content-Security-Policy"], "default-src 'self'"
    assert_not_includes response.headers["Content-Security-Policy"], "'unsafe-inline'"
    assert_select "a[href='#main-content']", I18n.t("forms.skip_to_content")
    assert_select "main#main-content[tabindex='-1']", count: 1
  end

  test "repeated failed sign-ins lock the account" do
    user = users(:tailor)

    Devise.maximum_attempts.times do
      post user_session_path, params: { user: { email: user.email, password: "incorrect-password" } }
    end

    assert user.reload.access_locked?
    post user_session_path, params: { user: { email: user.email, password: "Password-123!" } }
    assert_response :unprocessable_entity
    assert_select "h1", I18n.t("sessions.title")
  end
end
