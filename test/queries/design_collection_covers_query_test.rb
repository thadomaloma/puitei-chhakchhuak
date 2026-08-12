require "test_helper"

class DesignCollectionCoversQueryTest < ActiveSupport::TestCase
  setup do
    @collection = design_collections(:bridal)
    @item_scope = shops(:primary).design_collection_items
    @design_scope = Design.where(shop: shops(:primary))
  end

  test "uses the manual cover before an earlier eligible design" do
    first = designs(:blouse_reference)
    attach_image(first, "first.png")
    manual = create_design("Manual cover")
    add_to_collection(manual, position: 2)
    @collection.update!(cover_design: manual)

    assert_equal manual, resolved_cover
  end

  test "falls back to the first active collection design that has an image" do
    fallback = create_design("Fallback cover")
    add_to_collection(fallback, position: 2)

    assert_equal fallback, resolved_cover
  end

  test "ignores an archived manual cover and falls back safely" do
    first = designs(:blouse_reference)
    attach_image(first, "first.png")
    manual = create_design("Archived cover")
    add_to_collection(manual, position: 2)
    @collection.update!(cover_design: manual)
    manual.update_column(:active, false)

    assert_equal first, resolved_cover
  end

  test "returns nil for an empty collection" do
    empty = DesignCollection.create!(
      shop: shops(:primary), created_by: users(:manager), name: "Empty collection", visibility: :private
    )

    result = query([ empty ])
    assert_nil result[empty.id]
  end

  test "cover loading query count stays bounded across multiple collections" do
    collections = 5.times.map do |index|
      collection = DesignCollection.create!(
        shop: shops(:primary), created_by: users(:manager), name: "Query count #{index}", visibility: :private
      )
      design = create_design("Query count design #{index}")
      DesignCollectionItem.create!(
        shop: shops(:primary), design_collection: collection, design: design,
        added_by: users(:manager), position: 1
      )
      collection
    end

    query_count = sql_query_count { query(collections) }
    assert_operator query_count, :<=, 6
  end

  private

  def query(collections = [ @collection ])
    DesignCollectionCoversQuery.new(
      collections: collections, item_scope: @item_scope, design_scope: @design_scope
    ).call
  end

  def resolved_cover
    query[@collection.id]
  end

  def create_design(title)
    design = Design.new(
      shop: shops(:primary), uploaded_by: users(:manager), rights_confirmed_by: users(:manager),
      rights_confirmed_at: Time.current, title: title, garment_type: "blouse"
    )
    attach_image(design, "#{title.parameterize}.png")
    design.save!
    design
  end

  def attach_image(design, filename)
    design.images.attach(io: File.open(Rails.root.join("public/icon.png")), filename: filename, content_type: "image/png")
  end

  def add_to_collection(design, position:)
    DesignCollectionItem.create!(
      shop: shops(:primary), design_collection: @collection, design: design,
      added_by: users(:manager), position: position
    )
  end

  def sql_query_count
    count = 0
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      count += 1 unless payload[:name].in?([ "SCHEMA", "CACHE" ])
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    count
  end
end
