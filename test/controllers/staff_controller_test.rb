require "test_helper"

class StaffControllerTest < ActionDispatch::IntegrationTest
  test "manager views staff directory and creates operational account" do
    sign_in users(:manager)
    get staff_index_path
    assert_response :success
    assert_select "h1", I18n.t("staff.directory")

    assert_difference("User.count") do
      post staff_index_path, params: {
        user: {
          name: "Workshop Tailor", email: "workshop-tailor@example.test", role: "tailor",
          joined_on: Date.current, password: "Password-123!", password_confirmation: "Password-123!"
        }
      }
    end
    staff = User.order(:id).last
    assert_redirected_to staff_path(staff)
    assert_equal users(:manager).branch, staff.branch
    assert_equal "staff_created", staff.staff_events.last.event_type
  end

  test "manager cannot create or update manager-level accounts" do
    sign_in users(:manager)

    assert_no_difference("User.count") do
      post staff_index_path, params: {
        user: {
          name: "Unauthorized Manager", email: "unauthorized-manager@example.test", role: "manager",
          joined_on: Date.current, password: "Password-123!", password_confirmation: "Password-123!"
        }
      }
    end
    assert_redirected_to root_path

    patch staff_path(users(:tailor)), params: { user: { role: "manager" } }
    assert_redirected_to root_path
    assert users(:tailor).reload.tailor?
  end

  test "owner updates compensation and manager cannot submit it" do
    sign_in users(:owner)
    patch staff_path(users(:tailor)), params: { user: { pay_basis: "piece_rate", pay_rate: 850 } }
    assert_redirected_to staff_path(users(:tailor))
    assert users(:tailor).reload.pay_piece_rate?
    assert_equal 850.to_d, users(:tailor).pay_rate

    sign_out users(:owner)
    sign_in users(:manager)
    patch staff_path(users(:cutting)), params: { user: { pay_basis: "daily", pay_rate: 999 } }
    assert_equal 0.to_d, users(:cutting).reload.pay_rate
  end

  test "manager archives staff but cannot archive self" do
    sign_in users(:manager)

    patch archive_staff_path(users(:tailor))
    assert_redirected_to staff_index_path
    assert_not users(:tailor).reload.active?

    patch archive_staff_path(users(:manager))
    assert_redirected_to root_path
    assert users(:manager).reload.active?
  end

  test "archiving one tenant membership preserves another tenant login" do
    foreign_branch = Branch.create!(
      shop: shops(:foreign), name: "Foreign Staff Studio", code: "FOREIGN-STAFF", locale: "en", time_zone: "Asia/Kolkata"
    )
    Membership.create!(
      shop: shops(:foreign), branch: foreign_branch, user: users(:tailor), role: :tailor,
      employee_code: "STF-FOREIGN-STAFF-0001", joined_on: Date.current, accepted_at: Time.current
    )
    sign_in users(:manager)

    patch archive_staff_path(users(:tailor))

    assert_not memberships(:tailor_primary).reload.active?
    assert users(:tailor).reload.active?
    get staff_index_path
    assert_select "a[href='#{staff_path(users(:tailor))}']", count: 0
    get staff_index_path, params: { archived: "1" }
    assert_select "a[href='#{staff_path(users(:tailor))}']", minimum: 1
  end

  test "staff can view own profile but not another branch" do
    sign_in users(:tailor)
    get staff_path(users(:tailor))
    assert_response :success
    get staff_path(users(:second_manager))
    assert_response :not_found
    get staff_index_path
    assert_redirected_to root_path
  end
end
