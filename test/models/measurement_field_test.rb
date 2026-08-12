require "test_helper"

class MeasurementFieldTest < ActiveSupport::TestCase
  test "normalizes a human field key" do
    field = MeasurementField.new(measurement_template: measurement_templates(:shirt), key: "Sleeve Round", label: "Sleeve round")
    field.valid?

    assert_equal "sleeve_round", field.key
  end
end
