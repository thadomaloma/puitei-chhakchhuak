require "test_helper"

class TenantIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @foreign_branch = Branch.create!(
      shop: shops(:foreign), name: "Foreign Studio", code: "FOREIGN", locale: "en", time_zone: "Asia/Kolkata"
    )
    @foreign_owner = User.create!(
      name: "Foreign Owner", email: "foreign-owner@example.test", password: "Password-123!",
      branch: @foreign_branch, role: :owner, active: true
    )
    Membership.create!(
      shop: shops(:foreign), user: @foreign_owner, branch: @foreign_branch, role: :owner,
      employee_code: @foreign_owner.employee_code, joined_on: @foreign_owner.joined_on, accepted_at: Time.current
    )
    @foreign_customer = Customer.create!(
      branch: @foreign_branch, full_name: "Foreign Customer", phone_number: "9862407777", preferred_language: "en"
    )
    @foreign_profile = MeasurementProfile.create!(
      customer: @foreign_customer, measurement_template: measurement_templates(:blouse), name: "Foreign blouse", unit: "inches"
    )
    @foreign_measurement = @foreign_profile.record_measurement(
      created_by: @foreign_owner, measured_on: Date.current, values: { "bust" => "36", "waist" => "30" }
    )
    @foreign_order = Order.create!(
      branch: @foreign_branch, customer: @foreign_customer, created_by: @foreign_owner,
      ordered_on: Date.current, delivery_date: 1.week.from_now.to_date,
      order_items_attributes: {
        "0" => { measurement_id: @foreign_measurement.id, garment_name: "Foreign garment", quantity: 1, unit_price: 1000 }
      }
    )
    @foreign_order.confirm!
    @foreign_payment = @foreign_order.record_payment(
      received_by: @foreign_owner, amount: 1000, payment_method: :cash, paid_on: Date.current
    )
    ProductionTask.where(order_item_id: @foreign_order.order_items.select(:id))
      .update_all(status: ProductionTask.statuses[:completed], completed_at: Time.current, completed_by_id: @foreign_owner.id)
    @foreign_delivery = @foreign_order.deliver!(
      actor: @foreign_owner,
      attributes: {
        recipient_name: @foreign_customer.full_name, collection_method: :customer_pickup,
        acknowledged_by: @foreign_customer.full_name, recipient_acknowledged: true,
        quality_checked: true, garment_count_verified: true, payment_status_confirmed: true, packaging_complete: true
      }
    )
    sign_in users(:owner)
  end

  test "tenant owner cannot view foreign customer measurement order payment or delivery" do
    get customer_path(@foreign_customer)
    assert_response :not_found
    sign_in users(:owner)
    get customer_measurement_profile_measurement_path(@foreign_customer, @foreign_profile, @foreign_measurement)
    assert_response :not_found
    sign_in users(:owner)
    get order_path(@foreign_order)
    assert_response :not_found
    sign_in users(:owner)
    get payment_path(@foreign_payment)
    assert_response :not_found
    sign_in users(:owner)
    get delivery_path(@foreign_delivery)
    assert_response :not_found
  end

  test "tenant owner cannot mutate or destroy foreign records" do
    patch customer_path(@foreign_customer), params: { customer: { full_name: "Compromised" } }
    assert_response :not_found
    sign_in users(:owner)
    delete customer_path(@foreign_customer)
    assert_response :not_found
    assert_equal "Foreign Customer", @foreign_customer.reload.full_name
    assert @foreign_customer.active?
  end

  test "submitted tenant identifiers cannot move a record across shops" do
    assert_no_difference("Customer.count") do
      post customers_path, params: {
        customer: {
          full_name: "Scoped Customer", phone_number: "9862408888", preferred_language: "en",
          shop_id: shops(:foreign).id, branch_id: @foreign_branch.id
        }
      }
    end
    assert_response :not_found
  end
end
