require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:receptionist) }

  test "lists active customers and searches by phone" do
    get customers_path, params: { query: "0001" }

    assert_response :success
    assert_select "h1", "Customers"
    assert_select "a[href='#{customer_path(customers(:alice))}']"
    assert_select "a[href='#{customer_path(customers(:other_branch))}']", count: 0
  end

  test "searches by WhatsApp number" do
    customers(:alice).update_column(:whatsapp_number, "9123456789")

    get customers_path, params: { query: "9123456789" }

    assert_response :success
    assert_select "a[href='#{customer_path(customers(:alice))}']"
  end

  test "filters archived customers" do
    get customers_path, params: { status: "archived" }

    assert_response :success
    assert_select "a[href='#{customer_path(customers(:bina))}']"
    assert_select "a[href='#{customer_path(customers(:alice))}']", count: 0
  end

  test "paginates the customer directory" do
    now = Time.current
    Customer.insert_all!(21.times.map do |index|
      {
        shop_id: shops(:primary).id, branch_id: branches(:main).id, customer_code: "CUS-PAGE#{index.to_s.rjust(4, '0')}",
        full_name: "Paged Customer #{index}", phone_number: "88000#{index.to_s.rjust(5, '0')}",
        preferred_language: "en", gender: 0, active: true, created_at: now + index.seconds, updated_at: now
      }
    end)

    get customers_path, params: { page: 2 }

    assert_response :success
    assert_select "nav[aria-label='Pagination']"
    assert_select "a[href='#{customer_path(customers(:alice))}']"
  end

  test "renders customer profile tabs and measurement workspace" do
    get customer_path(customers(:alice), tab: "measurements")

    assert_response :success
    assert_select "nav[aria-label='Customer profile sections']"
    assert_select "a[aria-current='page']", text: "Measurements"
    assert_select "a[href='#{customer_measurement_profile_path(customers(:alice), measurement_profiles(:alice_blouse))}']"
  end

  test "renders the minimal new customer form" do
    get new_customer_path

    assert_response :success
    assert_select "input#customer_full_name"
    assert_select "input#customer_phone_number"
  end

  test "renders the edit form with legacy optional fields still available" do
    customers(:alice).update!(gender: 1, date_of_birth: Date.new(1990, 1, 1), address: "Some address", notes: "note")

    get edit_customer_path(customers(:alice))

    assert_response :success
  end

  test "creates a customer in the current branch" do
    assert_difference("Customer.count") do
      post customers_path, params: {
        customer: { full_name: "New Person", phone_number: "+91 90000 00001", preferred_language: "en", gender: "unspecified" }
      }
    end

    customer = Customer.order(:id).last
    assert_redirected_to customer_path(customer)
    assert_equal users(:receptionist).branch, customer.branch
  end

  test "renders validation errors for an invalid customer" do
    assert_no_difference("Customer.count") do
      post customers_path, params: { customer: { full_name: "", phone_number: "123", preferred_language: "en" } }
    end

    assert_response :unprocessable_content
    assert_select "[role='alert']"
  end

  test "suggests the existing customer instead of a raw uniqueness error" do
    assert_no_difference("Customer.count") do
      post customers_path, params: { customer: { full_name: "Someone Else", phone_number: customers(:alice).phone_number, preferred_language: "en" } }
    end

    assert_response :unprocessable_content
    assert_select "a[href='#{customer_path(customers(:alice))}']"
    assert_no_match(/Phone number has already been taken/, response.body)
  end

  test "updates customer details" do
    patch customer_path(customers(:alice)), params: { customer: { full_name: "Alice Updated", phone_number: customers(:alice).phone_number, preferred_language: "lus" } }

    assert_redirected_to customer_path(customers(:alice))
    assert_equal "Alice Updated", customers(:alice).reload.full_name
    assert_equal "lus", customers(:alice).preferred_language
  end

  test "archives instead of deleting" do
    customer = customers(:alice)

    assert_no_difference("Customer.count") { delete customer_path(customer) }
    assert_redirected_to customers_path
    assert_not customer.reload.active?
  end

  test "production staff are denied customer access" do
    sign_out users(:receptionist)
    sign_in users(:tailor)

    get customers_path

    assert_redirected_to root_path
  end

  test "cashier cannot archive a customer" do
    sign_out users(:receptionist)
    sign_in users(:cashier)

    delete customer_path(customers(:alice))

    assert_redirected_to root_path
    assert customers(:alice).reload.active?
  end
end
