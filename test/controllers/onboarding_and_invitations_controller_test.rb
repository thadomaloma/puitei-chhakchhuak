require "test_helper"

class OnboardingAndInvitationsControllerTest < ActionDispatch::IntegrationTest
  test "owner can complete basic shop onboarding" do
    sign_in users(:owner)

    get onboarding_path
    assert_response :success
    assert_select "h1", I18n.t("saas.setup_shop")

    patch onboarding_path, params: {
      shop: {
        name: "Updated Studio", country: "India", phone: "+91 98624 01111",
        whatsapp_number: "+91 98624 01111", address: "Aizawl", currency: "INR",
        time_zone: "Asia/Kolkata", measurement_unit: "inches", invoice_prefix: "UPD",
        default_delivery_days: 10
      }
    }

    assert_redirected_to root_path
    assert shops(:primary).reload.onboarding_complete?
    assert_equal "Updated Studio", shops(:primary).name
    assert_equal "+91 98624 01111", branches(:main).reload.phone
  end

  test "owner can set the shop's instagram username" do
    sign_in users(:owner)

    patch onboarding_path, params: {
      shop: {
        name: "Updated Studio", country: "India", phone: "+91 98624 01111",
        address: "Aizawl", currency: "INR", time_zone: "Asia/Kolkata", measurement_unit: "inches",
        invoice_prefix: "UPD", default_delivery_days: 10, instagram_username: "@puiteichhakchhuak"
      }
    }

    assert_redirected_to root_path
    assert_equal "puiteichhakchhuak", branches(:main).shop_setting.reload.instagram_username
  end

  test "manager can send a tenant-scoped expiring invitation" do
    sign_in users(:manager)

    get staff_invitations_path
    assert_response :success

    assert_difference("StaffInvitation.count", 1) do
      assert_enqueued_emails 1 do
        post staff_invitations_path, params: {
          staff_invitation: {
            email: "new-tailor@example.test", role: "tailor", branch_id: branches(:main).id
          }
        }
      end
    end

    invitation = StaffInvitation.order(:id).last
    assert_redirected_to staff_invitations_path
    assert_equal shops(:primary), invitation.shop
    assert invitation.usable?
    assert_not_nil invitation.token_digest
  end
end
