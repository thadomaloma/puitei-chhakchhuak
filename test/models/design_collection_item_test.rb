require "test_helper"

class DesignCollectionItemTest < ActiveSupport::TestCase
  test "prevents duplicate membership" do
    duplicate = DesignCollectionItem.new(
      shop: shops(:primary), design_collection: design_collections(:bridal), design: designs(:blouse_reference),
      added_by: users(:manager)
    )

    assert_not duplicate.valid?
    assert duplicate.errors[:design_id].any?
  end

  test "rejects a design from another shop" do
    item = DesignCollectionItem.new(
      shop: shops(:primary), design_collection: design_collections(:bridal), design: designs(:foreign_reference),
      added_by: users(:manager)
    )

    assert_not item.valid?
    assert item.errors[:design].any?
  end

  test "removing membership preserves the design" do
    item = design_collection_items(:bridal_blouse)
    design = item.design

    assert_no_difference("Design.count") { item.destroy! }
    assert Design.exists?(design.id)
  end
end
