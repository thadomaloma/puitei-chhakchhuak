require "test_helper"

class DesignCollectionTest < ActiveSupport::TestCase
  test "normalizes and uniquely identifies active names within a shop" do
    collection = DesignCollection.new(
      shop: shops(:primary), created_by: users(:manager), name: "  New   Season  ", visibility: :private
    )

    assert collection.valid?
    assert_equal "New Season", collection.name

    duplicate = collection.dup
    duplicate.name = "new season"
    collection.save!

    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
  end

  test "requires its creator to have an active membership in the shop" do
    collection = DesignCollection.new(
      shop: shops(:foreign), created_by: users(:manager), name: "Wrong actor", visibility: :private
    )

    assert_not collection.valid?
    assert collection.errors[:created_by].any?
  end

  test "searches collection name and description" do
    assert_includes DesignCollection.search("ceremony"), design_collections(:bridal)
    assert_includes DesignCollection.search("  bridal   "), design_collections(:bridal)
    assert_includes DesignCollection.search("idal Coll"), design_collections(:bridal)
    assert_not_includes DesignCollection.search("unrelated"), design_collections(:bridal)
    assert_equal DesignCollection.count, DesignCollection.search("  ").count
  end

  test "normalizes and caps search input before building SQL" do
    assert_equal "Bridal Collection", DesignCollection.normalize_search_query("  Bridal   Collection  ")
    assert_equal SearchQueryNormalization::SEARCH_QUERY_MAX_LENGTH,
      DesignCollection.normalize_search_query("x" * 500).length
  end

  test "escapes wildcard characters in search input" do
    collection = DesignCollection.create!(
      shop: shops(:primary), created_by: users(:manager), name: "100% Silk", visibility: :private
    )

    assert_equal [ collection.id ], shops(:primary).design_collections.search("%").pluck(:id)
    assert_empty shops(:primary).design_collections.search("_missing_")
  end

  test "ordered scope remains stable for equal positions and names" do
    first = DesignCollection.create!(
      shop: shops(:primary), created_by: users(:manager), name: "Alpha", visibility: :private, position: 4
    )
    second = DesignCollection.create!(
      shop: shops(:primary), created_by: users(:manager), name: "Beta", visibility: :private, position: 4
    )

    assert_equal [ first.id, second.id ], shops(:primary).design_collections.where(id: [ second.id, first.id ]).ordered.pluck(:id)
  end

  test "accepts an active same-shop collection design with an image as cover" do
    collection = design_collections(:bridal)
    design = designs(:blouse_reference)
    attach_image(design)

    assert collection.update(cover_design: design)
    assert_equal design, collection.reload.cover_design
  end

  test "rejects cover designs outside the collection or shop" do
    collection = design_collections(:bridal)
    outside_design = build_design("Outside design")
    foreign_design = designs(:foreign_reference)
    attach_image(foreign_design)

    collection.cover_design = outside_design
    assert_not collection.valid?
    assert_includes collection.errors[:cover_design], "must belong to the collection"

    collection.cover_design = foreign_design
    assert_not collection.valid?
    assert_includes collection.errors[:cover_design], "must belong to the collection shop"
  end

  test "rejects an archived design as cover" do
    collection = design_collections(:bridal)
    design = designs(:blouse_reference)
    attach_image(design)
    design.update_column(:active, false)

    collection.cover_design = design
    assert_not collection.valid?
    assert_includes collection.errors[:cover_design], "must be active"
  end

  private

  def build_design(title)
    design = Design.new(
      shop: shops(:primary), uploaded_by: users(:manager), rights_confirmed_by: users(:manager),
      rights_confirmed_at: Time.current, title: title, garment_type: "blouse"
    )
    attach_image(design)
    design.save!
    design
  end

  def attach_image(design)
    design.images.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "cover.png", content_type: "image/png")
  end
end
