require "test_helper"

class DesignPolicyTest < ActiveSupport::TestCase
  setup do
    Current.membership = memberships(:manager_primary)
    @design = designs(:blouse_reference)
  end

  test "active tenant staff can browse the studio" do
    %i[owner manager receptionist cashier tailor cutting embroidery ironing].each do |role|
      Current.membership = memberships("#{role}_primary")
      assert DesignPolicy.new(users(role), @design).show?, "expected #{role} to view designs"
    end
  end

  test "front desk roles manage and only leaders archive" do
    Current.membership = memberships(:receptionist_primary)
    assert DesignPolicy.new(users(:receptionist), @design).update?
    assert_not DesignPolicy.new(users(:receptionist), @design).archive?

    Current.membership = memberships(:manager_primary)
    assert DesignPolicy.new(users(:manager), @design).archive?
  end

  test "normal tenant users cannot edit platform library records" do
    @design.visibility = :platform_library
    assert_not DesignPolicy.new(users(:manager), @design).update?
  end

  test "scope is restricted to the current shop" do
    scope = DesignPolicy::Scope.new(users(:manager), Design.all).resolve
    assert_includes scope, @design
    assert_not_includes scope, designs(:foreign_reference)
  end
end
