require "test_helper"

class BranchTest < ActiveSupport::TestCase
  test "normalizes code and creates default settings" do
    branch = Branch.create!(shop: shops(:primary), name: "New Studio", code: " new ")

    assert_equal "NEW", branch.code
    assert_equal "New Studio", branch.shop_setting.shop_name
  end

  test "requires a unique business code" do
    duplicate = Branch.new(shop: shops(:primary), name: "Duplicate", code: branches(:main).code)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "database rejects an invalid code even when validations are bypassed" do
    branch = Branch.new(shop: shops(:primary), name: "Invalid", code: "not valid")

    assert_raises(ActiveRecord::StatementInvalid) { branch.save!(validate: false) }
  end
end
