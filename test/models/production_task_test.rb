require "test_helper"

class ProductionTaskTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => {
          measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Embroidered blouse",
          quantity: 1, unit_price: 1500, requires_embroidery: true
        }
      }
    )
    @order.confirm!
    @tasks = @order.order_items.first.production_tasks.index_by(&:stage)
  end

  test "confirmation creates the ordered route including optional embroidery" do
    assert_equal %w[cutting embroidery tailoring finishing], @order.order_items.first.production_tasks.pluck(:stage)
    assert_equal [ 0, 1, 2, 3 ], @order.order_items.first.production_tasks.pluck(:position)
    assert_equal 0, @order.production_progress
  end

  test "a stage cannot start before its predecessor is finished" do
    error = assert_raises(ProductionTask::InvalidTransition) { @tasks.fetch("tailoring").start!(users(:tailor)) }
    assert_equal "Complete the earlier stages first", error.message
    assert @tasks.fetch("tailoring").reload.pending?
  end

  test "production staff can claim start and complete their matching stage with audit events" do
    task = @tasks.fetch("cutting")

    task.claim!(users(:cutting))
    task.start!(users(:cutting))
    task.complete!(users(:cutting), notes: "Pattern checked")

    assert task.reload.completed?
    assert_equal users(:cutting), task.completed_by
    assert_equal "Pattern checked", task.notes
    assert_equal %w[claimed started completed], task.production_events.reorder(:created_at).pluck(:event_type)
    assert_equal %w[pending in_progress], task.production_events.reorder(:created_at).where.not(to_status: nil).pluck(:from_status)
  end

  test "a mismatched role cannot claim a stage" do
    assert_raises(ProductionTask::InvalidTransition) { @tasks.fetch("cutting").claim!(users(:tailor)) }
    assert_nil @tasks.fetch("cutting").reload.assigned_to
  end

  test "manager assignment validates the assignee role" do
    cutting = @tasks.fetch("cutting")

    cutting.assign!(users(:manager), users(:cutting))
    assert_equal users(:cutting), cutting.reload.assigned_to
    assert_equal "assigned", cutting.production_events.first.event_type
    assert_raises(ProductionTask::InvalidTransition) { @tasks.fetch("embroidery").assign!(users(:manager), users(:tailor)) }
  end

  test "manager can skip and reopen a stage but not while later work is complete" do
    cutting = @tasks.fetch("cutting")
    cutting.skip!(users(:manager), notes: "Pre-cut fabric")

    assert cutting.reload.skipped?
    cutting.reopen!(users(:manager), notes: "Needs adjustment")
    assert cutting.reload.pending?
    assert_equal "reopened", cutting.production_events.first.event_type

    cutting.skip!(users(:manager))
    embroidery = @tasks.fetch("embroidery")
    embroidery.skip!(users(:manager))
    tailoring = @tasks.fetch("tailoring")
    tailoring.start!(users(:tailor))
    tailoring.complete!(users(:tailor))

    assert_raises(ProductionTask::InvalidTransition) { cutting.reopen!(users(:manager)) }
  end

  test "production progress reaches one hundred when every task is finished" do
    @tasks.fetch("cutting").skip!(users(:manager))
    @tasks.fetch("embroidery").skip!(users(:manager))
    @tasks.fetch("tailoring").skip!(users(:manager))
    @tasks.fetch("finishing").skip!(users(:manager))

    assert_equal 100, @order.reload.production_progress
    assert @order.production_complete?
  end

  test "manager assignment notifies the assignee once" do
    cutting = @tasks.fetch("cutting")

    cutting.assign!(users(:manager), users(:cutting))

    notification = Notification.find_by(recipient: users(:cutting), notification_type: :work_assigned, notifiable: @order)
    assert_not_nil notification
    assert_equal users(:manager), notification.actor

    assert_no_difference("Notification.count") { cutting.assign!(users(:manager), users(:cutting)) }
  end

  test "production events are immutable" do
    @tasks.fetch("cutting").claim!(users(:cutting))
    event = @tasks.fetch("cutting").production_events.first

    assert event.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(notes: "Changed") }
  end
end
