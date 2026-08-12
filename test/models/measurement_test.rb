require "test_helper"

class MeasurementTest < ActiveSupport::TestCase
  test "normalizes decimal values without floating point" do
    measurement = measurement_profiles(:alice_blouse).measurements.new(
      version: 2, created_by: users(:receptionist), measured_on: Date.current,
      values: { "bust" => "36.125", "waist" => "30" }
    )

    assert measurement.valid?
    assert_equal({ "bust" => "36.125", "waist" => "30.0" }, measurement.values)
  end

  test "requires template fields and rejects unknown values" do
    measurement = measurement_profiles(:alice_blouse).measurements.new(
      version: 2, created_by: users(:receptionist), measured_on: Date.current,
      values: { "bust" => "36", "mystery" => "10" }
    )

    assert_not measurement.valid?
    assert measurement.errors[:values].any? { |message| message.include?("unknown") }
    assert measurement.errors[:values].any? { |message| message.include?("Waist") }
  end

  test "copy records its source without changing the original" do
    original = measurements(:alice_blouse_v1)
    copy = original.measurement_profile.record_measurement(
      created_by: users(:receptionist), copied_from: original,
      measured_on: Date.current, values: original.values
    )

    assert_equal original, copy.copied_from
    assert_equal 1, original.reload.version
    assert_equal 2, copy.version
  end
end
