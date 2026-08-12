require "test_helper"

class MeasurementPolicyTest < ActiveSupport::TestCase
  test "customer-facing measurement roles can open the library" do
    assert MeasurementProfilePolicy.new(users(:manager), MeasurementProfile).index?
    assert MeasurementProfilePolicy.new(users(:receptionist), MeasurementProfile).index?
    assert_not MeasurementProfilePolicy.new(users(:cashier), MeasurementProfile).index?
    assert_not MeasurementProfilePolicy.new(users(:tailor), MeasurementProfile).index?
  end

  test "receptionist can record a measurement in their branch" do
    measurement = measurement_profiles(:alice_blouse).measurements.new

    assert MeasurementPolicy.new(users(:receptionist), measurement).create?
  end

  test "cashier and production staff cannot open measurement history" do
    measurement = measurements(:alice_blouse_v1)

    assert_not MeasurementPolicy.new(users(:cashier), measurement).show?
    assert_not MeasurementPolicy.new(users(:tailor), measurement).show?
  end

  test "manager cannot access a profile from another branch" do
    profile = measurement_profiles(:other_shirt)

    assert_not MeasurementProfilePolicy.new(users(:manager), profile).show?
  end
end
