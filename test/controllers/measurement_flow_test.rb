require "test_helper"

class MeasurementFlowTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:receptionist) }

  test "creates a garment profile then records its first version" do
    customer = customers(:alice)
    template = measurement_templates(:shirt)

    assert_difference("MeasurementProfile.count") do
      post customer_measurement_profiles_path(customer), params: {
        measurement_profile: { measurement_template_id: template.id, name: "Festival shirt", unit: "inches" }
      }
    end

    profile = MeasurementProfile.order(:id).last
    assert_redirected_to new_customer_measurement_profile_measurement_path(customer, profile)

    assert_difference("Measurement.count") do
      post customer_measurement_profile_measurements_path(customer, profile), params: {
        measurement: { measured_on: Date.current, values: { chest: "40.5" }, notes: "First fitting" }
      }
    end

    assert_redirected_to customer_measurement_profile_path(customer, profile)
    assert_equal 1, profile.measurements.first.version
    assert_equal "40.5", profile.measurements.first.values.fetch("chest")
  end

  test "copy creates a new version and preserves the original" do
    profile = measurement_profiles(:alice_blouse)
    original = measurements(:alice_blouse_v1)

    assert_difference("Measurement.count") do
      post customer_measurement_profile_measurements_path(customers(:alice), profile), params: {
        measurement: {
          measured_on: Date.current, copied_from_id: original.id,
          values: original.values.merge("waist" => "31")
        }
      }
    end

    copy = profile.measurements.first
    assert_equal 2, copy.version
    assert_equal original, copy.copied_from
    assert_equal "30.0", original.reload.values.fetch("waist")
  end

  test "copy form identifies source and shows previous values" do
    profile = measurement_profiles(:alice_blouse)
    original = measurements(:alice_blouse_v1)

    get new_customer_measurement_profile_measurement_path(customers(:alice), profile, copy_from_id: original.id)

    assert_response :success
    assert_select "input[name='measurement[copied_from_id]'][value='#{original.id}']"
    assert_select "input[name='measurement[values][bust]'][value='36.0']"
    assert_select "p", text: /Previous: 36.0 in/
  end

  test "new form renders only the selected garment template fields" do
    profile = measurement_profiles(:alice_blouse)

    get new_customer_measurement_profile_measurement_path(customers(:alice), profile)

    assert_response :success
    assert_select "input[name='measurement[values][bust]'][inputmode='decimal']"
    assert_select "input[name='measurement[values][waist]']"
    assert_select "input[name='measurement[values][chest]']", count: 0
  end

  test "detail compares a new version with its predecessor" do
    profile = measurement_profiles(:alice_blouse)
    second = profile.record_measurement(
      created_by: users(:receptionist), measured_on: Date.current,
      values: measurements(:alice_blouse_v1).values.merge("waist" => "31")
    )

    get customer_measurement_profile_measurement_path(customers(:alice), profile, second)

    assert_response :success
    assert_select "h2", text: "Changed values"
    assert_select "span", text: "30.0"
    assert_select "span", text: "31.0"
  end

  test "rejects missing required values" do
    profile = measurement_profiles(:alice_blouse)

    assert_no_difference("Measurement.count") do
      post customer_measurement_profile_measurements_path(customers(:alice), profile), params: {
        measurement: { measured_on: Date.current, values: { sleeve_length: "17" } }
      }
    end

    assert_response :unprocessable_content
    assert_select "[role='alert']"
  end
end
