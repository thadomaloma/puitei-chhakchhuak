require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects guests to sign in" do
    get root_path

    assert_redirected_to new_user_session_path
  end

  test "renders operational dashboard and responsive navigation for manager" do
    order = create_order
    sign_in users(:manager)

    get root_path

    assert_response :success
    assert_select "h1", /Manager/
    assert_select "aside nav[aria-label='Primary navigation']"
    assert_select "nav[aria-label='Mobile navigation']" do
      assert_select "a, button", count: 5
      assert_select "a[href='#{payments_path}']"
      assert_select "a[href='#{new_order_path}']", count: 0
      assert_select "button[aria-controls='mobile-more-menu'][aria-expanded='false']"
    end
    assert_select "#mobile-more-menu[role]", count: 0
    assert_select "#mobile-more-menu section[role='dialog'][aria-modal='true']"
    assert_select "a[href='#{order_path(order)}']"
    assert_select "section[aria-label='Key business metrics']"
    assert_select "section[aria-labelledby='today-priorities-title']"
    assert_select "section[aria-labelledby='team-capacity-title']"
    assert_select "svg[aria-hidden='true']"
  end

  test "navigation exposes only authorized working modules" do
    sign_in users(:tailor)

    get root_path

    assert_response :success
    assert_select "aside a[href='#{production_path}']"
    assert_select "aside a[href='#{payments_path}']", count: 0
    assert_select "aside a[href='#{customers_path}']", count: 0
    assert_select "a[href='#{new_order_path}']", count: 0
    assert_select "h2", text: I18n.t("payments.billing"), count: 0
  end

  test "unauthorized redirects render accessible dismissible alert" do
    sign_in users(:tailor)

    get customers_path
    follow_redirect!

    assert_response :success
    assert_select "div[role='alert'][data-controller='flash']"
    assert_select "button[data-action='flash#dismiss'][aria-label='Dismiss message']"
  end

  test "owner dashboard includes authorized orders across branches" do
    main_order = create_order
    other_order = create_order(
      branch: branches(:second), customer: customers(:other_branch),
      measurement: measurements(:other_shirt_v1), creator: users(:second_manager)
    )
    sign_in users(:owner)

    get root_path

    assert_response :success
    assert_select "aside a[href='#{payment_setting_path}']", text: I18n.t("navigation.payment_settings")
    assert_select "a[href='#{order_path(main_order)}']"
    assert_select "a[href='#{order_path(other_order)}']"
  end

  private

  def create_order(branch: branches(:main), customer: customers(:alice), measurement: measurements(:alice_blouse_v1), creator: users(:receptionist))
    Order.create!(
      branch: branch, customer: customer, created_by: creator,
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurement.id, garment_name: "Studio garment", quantity: 1, unit_price: 1500 }
      }
    )
  end
end
