require "test_helper"

class MeasurementsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:receptionist) }

  test "lists measurement profiles from the current branch" do
    get measurements_path

    assert_response :success
    assert_select "h1", "Measurements"
    assert_select "main a[href='#{customers_path}']", count: 1
    assert_select "a[href='#{customer_measurement_profile_path(customers(:alice), measurement_profiles(:alice_blouse))}']"
    assert_select "a[href='#{customer_measurement_profile_path(customers(:other_branch), measurement_profiles(:other_shirt))}']", count: 0
  end

  test "sidebar and mobile menu link to the measurement library" do
    get measurements_path

    assert_response :success
    assert_select "a[href='#{measurements_path}']", minimum: 2
  end

  test "searches profiles by customer and garment" do
    get measurements_path, params: { query: "Blouse" }

    assert_response :success
    assert_select "a[href='#{customer_measurement_profile_path(customers(:alice), measurement_profiles(:alice_blouse))}']"

    get measurements_path, params: { query: "not-a-real-profile" }

    assert_response :success
    assert_select "h3", "No measurement profiles found"
    assert_select "main a[href='#{customers_path}']", count: 1
    assert_select "main a[href='#{measurements_path}']", text: "Clear filters"
  end

  test "owner can see profiles across branches" do
    sign_out users(:receptionist)
    sign_in users(:owner)

    get measurements_path

    assert_response :success
    assert_select "a[href='#{customer_measurement_profile_path(customers(:other_branch), measurement_profiles(:other_shirt))}']"
  end

  test "production staff cannot open the measurement library" do
    sign_out users(:receptionist)
    sign_in users(:tailor)

    get measurements_path

    assert_redirected_to root_path
  end
end
