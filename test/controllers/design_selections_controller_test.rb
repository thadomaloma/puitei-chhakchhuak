require "test_helper"

class DesignSelectionsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:manager) }

  test "staff can attach an in-scope design to an in-scope customer" do
    assert_difference("DesignSelection.count", 1) do
      post design_selections_path, params: {
        design_selection: { customer_id: customers(:carol).id, status: "approved", customer_note: "Preferred option" },
        design_ids: [ designs(:blouse_reference).id ]
      }
    end

    selection = DesignSelection.order(:id).last
    assert_redirected_to customer_path(customers(:carol), tab: "gallery")
    assert_equal users(:manager), selection.selected_by
    assert_equal "Preferred option", selection.customer_note
  end

  test "foreign tenant design cannot be attached" do
    assert_no_difference("DesignSelection.count") do
      post design_selections_path, params: {
        design_selection: { customer_id: customers(:alice).id, status: "interested" },
        design_ids: [ designs(:foreign_reference).id ]
      }
    end

    assert_response :not_found
  end

  test "selection can be updated and archived without deleting history" do
    selection = design_selections(:alice_blouse)

    patch design_selection_path(selection), params: { design_selection: { status: "approved" } }
    assert_redirected_to customer_path(customers(:alice), tab: "gallery")
    assert selection.reload.approved?

    assert_no_difference("DesignSelection.count") { delete design_selection_path(selection) }
    assert selection.reload.archived?
  end

  test "approval is timestamped and invalid transitions are rejected" do
    selection = design_selections(:alice_blouse)

    patch design_selection_path(selection), params: { design_selection: { status: "approved" } }
    assert selection.reload.approved_at.present?

    patch design_selection_path(selection), params: { design_selection: { status: "shortlisted" } }
    assert selection.reload.approved?
    assert_match(/cannot change/i, flash[:alert])
  end

  test "archived selection can be restored when no active duplicate exists" do
    selection = design_selections(:alice_blouse)
    selection.archive!

    patch restore_design_selection_path(selection)

    assert_not selection.reload.archived?
    assert_redirected_to customer_path(selection.customer, tab: "gallery", selection_status: "archived")
  end
end
