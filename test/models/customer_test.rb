require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "normalizes contact details and generates a customer code" do
    customer = Customer.create!(
      branch: branches(:main), full_name: "  New   Customer ", phone_number: "+91 98765-01234",
      email: " PERSON@EXAMPLE.TEST ", preferred_language: "en"
    )

    assert_equal "New Customer", customer.full_name
    assert_equal "919876501234", customer.phone_number
    assert_equal "person@example.test", customer.email
    assert_match(/\ACUS-[A-Z0-9]{8}\z/, customer.customer_code)
  end

  test "phone is unique within a branch but reusable in another branch" do
    duplicate = Customer.new(branch: branches(:main), full_name: "Duplicate", phone_number: customers(:alice).phone_number)
    other_branch = Customer.new(branch: branches(:second), full_name: "Allowed", phone_number: customers(:bina).phone_number)

    assert_not duplicate.valid?
    assert other_branch.valid?
  end

  test "search matches name phone and customer code" do
    assert_includes Customer.search("Chhangte"), customers(:alice)
    assert_includes Customer.search("0001"), customers(:alice)
    assert_includes Customer.search("CUS-ALICE"), customers(:alice)
  end

  test "archive preserves the record and history" do
    customer = customers(:alice)

    assert_no_difference("Customer.count") { customer.archive! }
    assert_not customer.reload.active?
    assert_equal 1, customer.measurements.count
  end
end
