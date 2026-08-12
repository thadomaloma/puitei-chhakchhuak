require "test_helper"

class DesignStudioCompletionTest < ActiveSupport::TestCase
  setup do
    Current.membership = memberships(:manager_primary)
  end

  test "selection links records without duplicating images and rejects cross-tenant relationships" do
    design = designs(:blouse_reference)
    image_count = design.images.count
    selection = DesignSelection.new(
      shop: shops(:primary), customer: customers(:other_branch), design: design,
      selected_by: users(:manager), status: :approved
    )

    assert selection.save
    assert_equal image_count, design.images.count

    selection.design = designs(:foreign_reference)
    assert_not selection.valid?
    assert_includes selection.errors[:design], "must belong to the selection shop"
  end

  test "active customer and design pair cannot be duplicated but archived history is preserved" do
    existing = design_selections(:alice_blouse)
    duplicate = existing.dup
    duplicate.selected_at = Time.current

    assert_not duplicate.valid?
    existing.archive!
    assert duplicate.save
  end

  test "favourites are user and tenant scoped" do
    favourite = DesignFavourite.new(shop: shops(:foreign), design: designs(:foreign_reference), user: users(:owner))

    assert_not favourite.valid?
    assert favourite.errors[:user].any?
  end

  test "share stores a digest and resolves only an active raw token" do
    share = DesignShare.new(
      shop: shops(:primary), customer: customers(:alice), created_by: users(:manager),
      expires_at: 2.days.from_now
    )

    assert share.save
    token = share.raw_token
    assert token.present?
    assert_not_equal token, share.token_digest
    assert_equal share, DesignShare.find_active_by_token(token)

    share.revoke!
    assert_nil DesignShare.find_active_by_token(token)
  end

  test "share items require an active customer-shareable tenant design" do
    item = DesignShareItem.new(
      shop: shops(:primary), design_share: design_shares(:alice_preview), design: designs(:foreign_reference)
    )

    assert_not item.valid?
    assert item.errors[:design].any?
  end

  test "AI provider is disabled until a real provider is configured" do
    request = ai_design_requests(:completed_concept)

    error = assert_raises(AiDesign::Unavailable) do
      AiDesign::Generate.new(shop: shops(:primary)).call(request)
    end
    assert_match(/not available/, error.message)
  end
end
