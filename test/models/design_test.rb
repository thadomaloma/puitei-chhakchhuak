require "test_helper"

class DesignTest < ActiveSupport::TestCase
  setup do
    @design = designs(:blouse_reference)
    attach_image(@design)
  end

  test "normalizes tags and uses existing garment taxonomy" do
    @design.tag_list = " Bridal, PEARL, bridal,  Hand work "

    assert @design.valid?
    assert_equal [ "bridal", "pearl", "hand work" ], @design.tags

    @design.garment_type = "invented-garment"
    assert_not @design.valid?
    assert @design.errors[:garment_type].any?
  end

  test "requires an authorized image and preserves at least one on removal" do
    design = Design.new(
      shop: shops(:primary), uploaded_by: users(:manager), rights_confirmed_by: users(:manager),
      rights_confirmed_at: Time.current, title: "No image", garment_type: "blouse"
    )

    assert_not design.valid?
    assert_includes design.errors[:images], "must include at least one image"

    @design.remove_image_ids = [ @design.images.attachments.first.id ]
    assert_not @design.valid?
  end

  test "searches useful design metadata and tags" do
    assert_includes Design.search("pearl"), @design
    assert_includes Design.search("silk"), @design
    assert_not_includes Design.search("denim"), @design
  end

  test "rejects tenant actors from another shop" do
    design = Design.new(
      shop: shops(:foreign), uploaded_by: users(:manager), rights_confirmed_by: users(:manager),
      rights_confirmed_at: Time.current, title: "Wrong tenant", garment_type: "shirt"
    )
    attach_image(design)

    assert_not design.valid?
    assert design.errors[:uploaded_by].any?
  end

  private

  def attach_image(design)
    design.images.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "design.png", content_type: "image/png")
  end
end
