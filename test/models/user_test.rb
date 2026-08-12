require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a production-strength password" do
    user = User.new(
      branch: branches(:main), name: "Secure User", email: "secure-user@example.test",
      role: :tailor, password: "short-pass1", password_confirmation: "short-pass1"
    )

    assert_not user.valid?
    assert_includes user.errors[:password], I18n.t("errors.messages.too_short", count: 12)
  end

  test "defines every Phase 1 role" do
    assert_equal %w[owner manager receptionist cashier tailor cutting_staff embroidery_staff ironing_staff], User.roles.keys
  end

  test "requires name, branch, and a known role" do
    user = User.new(email: "new@example.test", password: "Password-123!", role: 99)

    assert_not user.valid?
    assert user.errors.of_kind?(:name, :blank)
    assert user.errors.of_kind?(:branch, :blank)
    assert user.errors.of_kind?(:role, :inclusion)
  end

  test "inactive staff cannot authenticate" do
    assert_not users(:inactive).active_for_authentication?
  end

  test "staff cannot authenticate to an inactive branch" do
    user = users(:manager)
    user.branch.update!(active: false)

    assert_not user.active_for_authentication?
  end
end
