require "test_helper"

class MeasurementProfileTest < ActiveSupport::TestCase
  test "records sequential immutable versions" do
    profile = measurement_profiles(:alice_blouse)
    second = profile.record_measurement(
      created_by: users(:receptionist), measured_on: Date.current,
      values: { "bust" => "37.25", "waist" => "31" }
    )

    assert_equal 2, second.version
    assert second.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { second.update!(notes: "Changed") }
  end

  test "unit must be inches or centimetres" do
    profile = measurement_profiles(:alice_blouse)
    profile.unit = "yards"

    assert_not profile.valid?
  end
end
