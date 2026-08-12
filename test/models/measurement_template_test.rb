require "test_helper"

class MeasurementTemplateTest < ActiveSupport::TestCase
  test "normalizes garment type and exposes ordered fields" do
    template = MeasurementTemplate.new(name: "School Uniform", garment_type: "School Uniform")
    template.valid?

    assert_equal "school_uniform", template.garment_type
    assert_equal %w[bust waist sleeve_length], measurement_templates(:blouse).measurement_fields.map(&:key)
  end

  test "field keys are unique within a template" do
    duplicate = measurement_templates(:blouse).measurement_fields.new(key: "bust", label: "Duplicate")

    assert_not duplicate.valid?
  end
end
