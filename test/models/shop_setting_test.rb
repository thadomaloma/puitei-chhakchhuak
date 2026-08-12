require "test_helper"

class ShopSettingTest < ActiveSupport::TestCase
  test "allows only one settings record per branch" do
    duplicate = ShopSetting.new(branch: branches(:main), shop_name: "Other")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:branch_id], "has already been taken"
  end

  test "validates operational defaults" do
    setting = shop_settings(:main_settings)
    setting.assign_attributes(tax_rate: 101, default_delivery_days: 0, measurement_unit: "yards")

    assert_not setting.valid?
    assert setting.errors.of_kind?(:tax_rate, :less_than_or_equal_to)
    assert setting.errors.of_kind?(:default_delivery_days, :greater_than)
    assert setting.errors.of_kind?(:measurement_unit, :inclusion)
  end

  test "normalizes and validates owner payment identifiers" do
    setting = shop_settings(:main_settings)
    setting.update!(upi_id: "  ATELIER.Owner@OKAXIS ", gpay_number: "+91 98624-01111")

    assert_equal "atelier.owner@okaxis", setting.upi_id
    assert_equal "9862401111", setting.gpay_number
    assert setting.payment_profile_configured?

    setting.assign_attributes(upi_id: "not-an-id", gpay_number: "12345")
    assert_not setting.valid?
    assert setting.errors.of_kind?(:upi_id, :invalid)
    assert setting.errors.of_kind?(:gpay_number, :invalid)
  end

  test "allows an owner to clear optional payment identifiers" do
    setting = shop_settings(:main_settings)
    setting.update!(upi_id: "owner@okaxis", gpay_number: "9862401111")
    setting.update!(upi_id: "", gpay_number: "")

    assert_nil setting.upi_id
    assert_nil setting.gpay_number
    assert_not setting.payment_profile_configured?
  end
end
