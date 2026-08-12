require "test_helper"

class TenantFoundationTest < ActiveSupport::TestCase
  test "the current membership is the source of shop role" do
    membership = Membership.create!(
      shop: shops(:foreign), user: users(:owner), branch: foreign_branch,
      role: :manager, employee_code: "STF-FGN-0999", joined_on: Date.current, accepted_at: Time.current
    )

    Current.membership = membership

    assert_equal shops(:foreign), Current.shop
    assert users(:owner).manager?
    assert_not users(:owner).owner?
  end

  test "invitation token is stored as a digest and cannot be reused" do
    invitation = StaffInvitation.create!(
      shop: shops(:primary), branch: branches(:main), email: "invitee@example.test",
      role: :tailor, invited_by: users(:manager)
    )
    token = invitation.raw_token

    assert_not_equal token, invitation.token_digest
    assert_equal invitation, StaffInvitation.find_by_token(token)
    user = User.create!(
      name: "Invited Tailor", email: "invitee@example.test", password: "Password-123!",
      branch: branches(:main), role: :tailor, active: true
    )
    membership = invitation.accept!(user)

    assert membership.tailor?
    assert_not invitation.reload.usable?
    assert_raises(StaffInvitation::InvalidInvitation) { invitation.accept!(user) }
  end

  test "duplicate pending invitations are rejected within a shop" do
    attributes = {
      shop: shops(:primary), branch: branches(:main), email: "duplicate@example.test",
      role: :tailor, invited_by: users(:manager)
    }
    StaffInvitation.create!(attributes)
    duplicate = StaffInvitation.new(attributes)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "already has a pending invitation"
  end

  test "duplicate memberships are rejected" do
    duplicate = Membership.new(
      shop: shops(:primary), user: users(:owner), branch: branches(:main), role: :owner,
      employee_code: "STF-MAIN-0999", joined_on: Date.current
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:user_id, :taken)
  end

  test "expired invitation cannot be accepted" do
    invitation = StaffInvitation.create!(
      shop: shops(:primary), branch: branches(:main), email: "expired@example.test",
      role: :tailor, invited_by: users(:manager), expires_at: 1.minute.ago
    )
    user = User.create!(
      name: "Expired Invitee", email: "expired@example.test", password: "Password-123!",
      branch: branches(:main), role: :tailor, active: true
    )

    assert_not invitation.usable?
    assert_raises(StaffInvitation::InvalidInvitation) { invitation.accept!(user) }
  end

  private

  def foreign_branch
    @foreign_branch ||= Branch.create!(
      shop: shops(:foreign), name: "Foreign Main", code: "FGN", locale: "en", time_zone: "Asia/Kolkata"
    )
  end
end
