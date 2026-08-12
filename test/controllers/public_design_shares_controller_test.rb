require "test_helper"

class PublicDesignSharesControllerTest < ActionDispatch::IntegrationTest
  test "valid token exposes only customer-safe shared content without sign in" do
    get public_design_share_path(token: "alice-preview-token")

    assert_response :success
    assert_select "h1", text: design_shares(:alice_preview).title
    assert_includes response.body, designs(:blouse_reference).title
    assert_not_includes response.body, designs(:blouse_reference).internal_notes
    assert_not_includes response.body, customers(:bina).full_name
    assert_select "select[name='design_share_item[customer_reaction]']", count: 1
    assert design_shares(:alice_preview).reload.viewed_at.present?
  end

  test "invalid, expired, and revoked tokens are unavailable" do
    get public_design_share_path(token: "not-valid")
    assert_response :gone

    share = design_shares(:alice_preview)
    share.update_column(:expires_at, 1.minute.ago)
    get public_design_share_path(token: "alice-preview-token")
    assert_response :gone
  end

  test "customer feedback updates only the signed shared item" do
    item = design_share_items(:alice_blouse_share)
    token = item.signed_id(purpose: :design_share_feedback, expires_in: 1.hour)

    post public_design_share_feedback_path(token: "alice-preview-token"), params: {
      item_token: token,
      design_share_item: { customer_reaction: "shortlisted", customer_comment: "Please keep the neckline." }
    }

    assert_redirected_to public_design_share_path(token: "alice-preview-token", anchor: "design-#{item.id}")
    assert item.reload.customer_reaction_shortlisted?
    assert_equal "Please keep the neckline.", item.customer_comment
  end
end
