require "test_helper"

class DesignSharesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:manager) }

  test "creates a digest-backed private preview with scoped designs" do
    assert_difference([ "DesignShare.count", "DesignShareItem.count" ], 1) do
      post design_shares_path, params: {
        design_share: {
          customer_id: customers(:carol).id, title: "Private fitting shortlist",
          expires_at: 3.days.from_now, allow_feedback: "1"
        },
        design_ids: [ designs(:blouse_reference).id ]
      }
    end

    share = DesignShare.order(:id).last
    assert_response :created
    assert_select "input[readonly][value*='/s?token=']", count: 1
    assert_not_includes response.body, share.token_digest
  end

  test "foreign designs are never added to a share" do
    assert_no_difference([ "DesignShare.count", "DesignShareItem.count" ]) do
      post design_shares_path, params: {
        design_share: { customer_id: customers(:alice).id, expires_at: 3.days.from_now },
        design_ids: [ designs(:foreign_reference).id ]
      }
    end
    assert_response :unprocessable_content
  end

  test "revoking a share preserves the audit record" do
    share = design_shares(:alice_preview)
    assert_no_difference("DesignShare.count") { delete design_share_path(share) }

    assert_redirected_to design_shares_path
    assert share.reload.revoked_at.present?
  end
end
