require "test_helper"

class ProductionTasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Blouse", quantity: 1, unit_price: 1500 }
      }
    )
    @order.confirm!
    @cutting = @order.order_items.first.production_tasks.find_by!(stage: :cutting)
  end

  test "production user can open queue and move own task through its workflow" do
    sign_in users(:cutting)

    get production_path
    assert_response :success
    assert_select "#production-task-#{@cutting.id}"

    patch claim_production_task_path(@cutting)
    assert_redirected_to production_path
    patch start_production_task_path(@cutting)
    assert_redirected_to production_path
    patch complete_production_task_path(@cutting), params: { production_task: { notes: "Cut cleanly" } }
    assert_redirected_to production_path

    assert @cutting.reload.completed?
    assert_equal "Cut cleanly", @cutting.notes
  end

  test "queue renders stage workload, garment workflow, and measurement reference" do
    sign_in users(:manager)

    get production_path

    assert_response :success
    assert_select "h1", I18n.t("production.title")
    assert_select "a[href='#{production_path(stage: 'cutting')}']"
    assert_select "#production-task-#{@cutting.id} ol[aria-label='#{I18n.t('production.garment_workflow')}']"
    assert_select "#production-task-#{@cutting.id}", text: /Everyday blouse · v1/
    assert_select "select#production_task_#{@cutting.id}_assigned_to_id option[value='#{users(:cutting).id}']"
    assert_select "select#production_task_#{@cutting.id}_assigned_to_id option[value='#{users(:tailor).id}']", count: 0
  end

  test "searches the queue by garment, customer, and order number" do
    sign_in users(:manager)

    [ "Blouse", customers(:alice).full_name, @order.order_number ].each do |query|
      get production_path, params: { query: query }
      assert_response :success
      assert_select "#production-task-#{@cutting.id}"
    end

    get production_path, params: { query: "No matching workshop record" }
    assert_response :success
    assert_select "#production-task-#{@cutting.id}", count: 0
  end

  test "filters the queue by overdue delivery" do
    overdue_order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: 10.days.ago.to_date, delivery_date: 2.days.ago.to_date,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Overdue blouse", quantity: 1, unit_price: 1500 }
      }
    )
    overdue_order.confirm!
    overdue_task = overdue_order.order_items.first.production_tasks.first
    sign_in users(:manager)

    get production_path, params: { urgency: "overdue" }

    assert_response :success
    assert_select "#production-task-#{overdue_task.id}"
    assert_select "#production-task-#{@cutting.id}", count: 0
  end

  test "filters assigned work and renders immutable activity history" do
    @cutting.claim!(users(:cutting))
    sign_in users(:cutting)

    get production_path, params: { assignment: "mine" }

    assert_response :success
    assert_select "#production-task-#{@cutting.id}"
    assert_includes response.body, I18n.t("production.activity_history", count: 1)
    assert_includes response.body, I18n.t("production.events.claimed", actor: users(:cutting).name)
  end

  test "wrong production role is denied task actions" do
    sign_in users(:tailor)

    patch claim_production_task_path(@cutting)
    assert_redirected_to root_path
    assert_nil @cutting.reload.assigned_to
  end

  test "manager can assign and skip tasks" do
    sign_in users(:manager)

    patch assign_production_task_path(@cutting), params: { production_task: { assigned_to_id: users(:cutting).id } }
    assert_redirected_to production_path
    assert_equal users(:cutting), @cutting.reload.assigned_to

    patch skip_production_task_path(@cutting), params: { production_task: { notes: "Already cut" } }
    assert_redirected_to production_path
    assert @cutting.reload.skipped?
  end

  test "branch staff cannot access another branch task" do
    sign_in users(:manager)
    other_order = Order.create!(
      branch: branches(:second), customer: customers(:other_branch), created_by: users(:second_manager),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:other_shirt_v1).id, garment_name: "Shirt", quantity: 1, unit_price: 1500 }
      }
    )
    other_order.confirm!
    task = other_order.order_items.first.production_tasks.first

    patch skip_production_task_path(task)
    assert_response :not_found
    assert task.reload.pending?
  end
end
