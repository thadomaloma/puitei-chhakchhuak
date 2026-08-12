require "test_helper"

class DesignCollectionPolicyTest < ActiveSupport::TestCase
  setup do
    @collection = design_collections(:bridal)
  end

  test "active tenant staff may browse collections" do
    %i[owner manager receptionist cashier tailor cutting embroidery ironing].each do |role|
      Current.membership = memberships("#{role}_primary")
      assert DesignCollectionPolicy.new(users(role), @collection).show?, "expected #{role} to view collections"
    end
  end

  test "front desk roles manage while workshop and cashier roles cannot" do
    %i[owner manager receptionist].each do |role|
      Current.membership = memberships("#{role}_primary")
      assert DesignCollectionPolicy.new(users(role), @collection).manage_items?, "expected #{role} to manage collections"
      assert DesignCollectionPolicy.new(users(role), @collection).set_cover?, "expected #{role} to set collection covers"
    end

    %i[cashier tailor cutting embroidery ironing].each do |role|
      Current.membership = memberships("#{role}_primary")
      assert_not DesignCollectionPolicy.new(users(role), @collection).manage_items?, "expected #{role} to have read-only access"
      assert_not DesignCollectionPolicy.new(users(role), @collection).set_cover?, "expected #{role} not to set collection covers"
    end
  end

  test "scope is restricted to current shop" do
    Current.membership = memberships(:manager_primary)
    scope = DesignCollectionPolicy::Scope.new(users(:manager), DesignCollection.all).resolve

    assert_includes scope, @collection
    assert_not_includes scope, design_collections(:foreign_collection)
  end
end
