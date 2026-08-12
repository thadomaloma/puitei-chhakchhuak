require "test_helper"

class ShopSettingPolicyTest < ActiveSupport::TestCase
  test "only the tenant owner can view and update payment settings" do
    setting = shop_settings(:main_settings)

    assert ShopSettingPolicy.new(users(:owner), setting).show?
    assert ShopSettingPolicy.new(users(:owner), setting).update?
    assert_not ShopSettingPolicy.new(users(:manager), setting).show?
    assert_not ShopSettingPolicy.new(users(:cashier), setting).update?
  end

  test "an owner cannot access settings from another tenant" do
    foreign_branch = Branch.create!(
      shop: shops(:foreign), name: "Foreign Studio", code: "FOREIGN",
      locale: "en", time_zone: "Asia/Kolkata"
    )

    assert_not ShopSettingPolicy.new(users(:owner), foreign_branch.shop_setting).show?
  end
end
