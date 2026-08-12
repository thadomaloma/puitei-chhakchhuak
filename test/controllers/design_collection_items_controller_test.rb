require "test_helper"

class DesignCollectionItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:manager)
    @collection = design_collections(:bridal)
  end

  test "picker excludes designs already in the collection" do
    available = create_design("Available design")

    get new_design_collection_design_collection_item_path(@collection)

    assert_response :success
    assert_select "input[name='design_ids[]'][value='#{available.id}']", count: 1
    assert_select "input[name='design_ids[]'][value='#{designs(:blouse_reference).id}']", count: 0
  end

  test "adds multiple scoped designs without duplicates" do
    first = create_design("First available")
    second = create_design("Second available")

    assert_difference("DesignCollectionItem.count", 2) do
      post design_collection_design_collection_items_path(@collection), params: {
        design_ids: [ first.id, second.id, designs(:blouse_reference).id ]
      }
    end

    assert_redirected_to design_collection_path(@collection)
    assert_equal 3, @collection.reload.design_collection_items_count
  end

  test "foreign design cannot be attached through parameter manipulation" do
    assert_no_difference("DesignCollectionItem.count") do
      post design_collection_design_collection_items_path(@collection), params: {
        design_ids: [ designs(:foreign_reference).id ], shop_id: shops(:foreign).id
      }
    end

    assert_redirected_to new_design_collection_design_collection_item_path(@collection)
  end

  test "removes the membership without deleting the design" do
    item = design_collection_items(:bridal_blouse)
    design = item.design

    assert_difference("DesignCollectionItem.count", -1) do
      assert_no_difference("Design.count") do
        delete design_collection_design_collection_item_path(@collection, item)
      end
    end

    assert_redirected_to design_collection_path(@collection)
    assert Design.exists?(design.id)
  end

  test "removing the manual cover clears it without changing the remaining collection" do
    item = design_collection_items(:bridal_blouse)
    design = item.design
    design.images.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "cover.png", content_type: "image/png")
    @collection.update!(cover_design: design)

    delete design_collection_design_collection_item_path(@collection, item)

    assert_redirected_to design_collection_path(@collection)
    assert_nil @collection.reload.cover_design
    assert Design.exists?(design.id)
  end

  test "foreign collection cannot be used as an add target" do
    foreign = design_collections(:foreign_collection)

    post design_collection_design_collection_items_path(foreign), params: { design_ids: [ designs(:blouse_reference).id ] }

    assert_response :not_found
  end

  test "archived collection cannot add or remove designs" do
    item = design_collection_items(:bridal_blouse)
    available = create_design("Archived blocked design")
    @collection.archive!

    assert_no_difference("DesignCollectionItem.count") do
      post design_collection_design_collection_items_path(@collection), params: { design_ids: [ available.id ] }
    end
    assert_redirected_to root_path

    assert_no_difference("DesignCollectionItem.count") do
      delete design_collection_design_collection_item_path(@collection, item)
    end
    assert_redirected_to root_path
  end

  private

  def create_design(title)
    design = Design.new(
      shop: shops(:primary), uploaded_by: users(:manager), rights_confirmed_by: users(:manager),
      rights_confirmed_at: Time.current, title: title, garment_type: "blouse"
    )
    design.images.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "#{title.parameterize}.png", content_type: "image/png")
    design.save!
    design
  end
end
