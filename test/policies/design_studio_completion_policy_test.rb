require "test_helper"

class DesignStudioCompletionPolicyTest < ActiveSupport::TestCase
  test "front desk roles manage selections and shares while workshop roles cannot" do
    selection = design_selections(:alice_blouse)
    share = design_shares(:alice_preview)

    %i[owner manager receptionist].each do |role|
      Current.membership = memberships("#{role}_primary")
      assert DesignSelectionPolicy.new(users(role), selection).update?
      assert DesignSharePolicy.new(users(role), share).create?
    end

    %i[cashier tailor cutting embroidery ironing].each do |role|
      Current.membership = memberships("#{role}_primary")
      assert_not DesignSelectionPolicy.new(users(role), selection).create?
      assert_not DesignSharePolicy.new(users(role), share).create?
    end
  end

  test "selection and share scopes never include another shop" do
    Current.membership = memberships(:manager_primary)

    assert_equal [ shops(:primary).id ], DesignSelectionPolicy::Scope.new(users(:manager), DesignSelection.all).resolve.distinct.pluck(:shop_id)
    assert_equal [ shops(:primary).id ], DesignSharePolicy::Scope.new(users(:manager), DesignShare.all).resolve.distinct.pluck(:shop_id)
  end
end
