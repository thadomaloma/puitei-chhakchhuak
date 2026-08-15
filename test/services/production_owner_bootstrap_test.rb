require "test_helper"

class ProductionOwnerBootstrapTest < ActiveSupport::TestCase
  STRONG_PASSWORD = "V3ry-Long!Owner-Secret".freeze

  test "requires the owner credentials" do
    error = assert_raises(RuntimeError) { ProductionOwnerBootstrap.call!({}) }

    assert_includes error.message, "BOOTSTRAP_OWNER_EMAIL"
    assert_includes error.message, "BOOTSTRAP_OWNER_PASSWORD"
  end

  test "rejects weak or development passwords" do
    error = assert_raises(RuntimeError) do
      ProductionOwnerBootstrap.call!(
        "BOOTSTRAP_OWNER_EMAIL" => "new-owner@example.test",
        "BOOTSTRAP_OWNER_PASSWORD" => "TailorFlow-Dev-2026!"
      )
    end

    assert_includes error.message, "development passwords are forbidden"
  end

  test "creates an owner for a canonical shop without an active owner" do
    memberships(:owner_primary).update!(active: false)

    result = ProductionOwnerBootstrap.call!(
      "BOOTSTRAP_OWNER_EMAIL" => "production-owner@example.test",
      "BOOTSTRAP_OWNER_PASSWORD" => STRONG_PASSWORD,
      "BOOTSTRAP_OWNER_NAME" => "Production Owner",
      "BOOTSTRAP_BRANCH_CODE" => "MAIN"
    )

    assert result.created
    assert result.owner.owner?
    assert result.owner.valid_password?(STRONG_PASSWORD)
    assert_equal shops(:primary), result.shop
    assert_equal branches(:main), result.branch
    assert result.owner.memberships.owner.active.exists?(shop: result.shop)
  end

  test "is idempotent for the same active owner and does not reset the password" do
    result = ProductionOwnerBootstrap.call!(
      "BOOTSTRAP_OWNER_EMAIL" => users(:owner).email,
      "BOOTSTRAP_OWNER_PASSWORD" => STRONG_PASSWORD
    )

    assert_not result.created
    assert_equal users(:owner), result.owner
    assert users(:owner).valid_password?("Password-123!")
  end

  test "refuses to add a second active owner" do
    error = assert_raises(RuntimeError) do
      ProductionOwnerBootstrap.call!(
        "BOOTSTRAP_OWNER_EMAIL" => "another-owner@example.test",
        "BOOTSTRAP_OWNER_PASSWORD" => STRONG_PASSWORD
      )
    end

    assert_includes error.message, "already has an active owner"
  end
end
