require "test_helper"

class PaymentSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @setting = shop_settings(:main_settings)
  end

  test "owner can open the dedicated branch payment settings page" do
    sign_in users(:owner)

    get payment_setting_path

    assert_response :success
    assert_select "h1", I18n.t("payment_settings.heading")
    assert_select "form[action='#{payment_setting_path}'][method='post']"
    assert_select "input[name='shop_setting[upi_id]'][autocomplete='off']"
    assert_select "input[name='shop_setting[gpay_number]'][inputmode='numeric']"
    assert_select "a[href='#{payment_setting_path}'][aria-current='page']", minimum: 1
  end

  test "owner updates only the current branch profile with normalized values and an audit event" do
    sign_in users(:owner)
    other_setting = shop_settings(:second_settings)

    assert_difference("BusinessAuditEvent.where(action: 'payment_profile.updated').count", 1) do
      patch payment_setting_path, params: {
        shop_setting: { upi_id: "  Owner.Atelier@OKAXIS ", gpay_number: "+91 98624-01111" }
      }
    end

    assert_redirected_to payment_setting_path
    assert_equal "owner.atelier@okaxis", @setting.reload.upi_id
    assert_equal "9862401111", @setting.gpay_number
    assert_nil other_setting.reload.upi_id
    event = BusinessAuditEvent.where(action: "payment_profile.updated").order(:id).last
    assert_equal shops(:primary), event.shop
    assert_equal users(:owner), event.actor
    assert_equal @setting, event.auditable
    assert_equal %w[gpay_number upi_id], event.metadata.fetch("fields").sort
  end

  test "invalid payment identifiers render accessible errors without saving" do
    sign_in users(:owner)

    patch payment_setting_path, params: {
      shop_setting: { upi_id: "invalid", gpay_number: "12345" }
    }

    assert_response :unprocessable_content
    assert_select "[role='alert']"
    assert_nil @setting.reload.upi_id
    assert_nil @setting.gpay_number
  end

  test "manager cannot view or change owner payment identifiers" do
    sign_in users(:manager)

    get payment_setting_path
    assert_redirected_to root_path

    patch payment_setting_path, params: {
      shop_setting: { upi_id: "manager@okaxis", gpay_number: "9862401111" }
    }
    assert_redirected_to root_path
    assert_nil @setting.reload.upi_id
    assert_nil @setting.gpay_number
  end
end
