require "test_helper"

class DesignsControllerTest < ActionDispatch::IntegrationTest
  test "tenant user browses and filters the gallery" do
    sign_in users(:manager)

    get designs_path, params: { query: "Pearl", garment_type: "blouse" }

    assert_response :success
    assert_select "h1", I18n.t("designs.title")
    assert_select ".filter-command-bar"
    assert_select "nav[aria-label='#{I18n.t('designs.view')}'] a", count: 2
    assert_select "details summary", text: /#{I18n.t('designs.more_filters')}/
    assert_select ".filter-chip", minimum: 2
    assert_select "a[href='#{design_path(designs(:blouse_reference))}']", minimum: 1
    assert_not_includes response.body, designs(:foreign_reference).title
  end

  test "desktop filters preserve the active library context" do
    sign_in users(:manager)

    get designs_path, params: {
      query: "Pearl", garment_type: "blouse", visibility: "private",
      source_type: "original", archived: "1"
    }

    assert_response :success
    assert_select ".filter-command-bar input[type='hidden'][name='visibility'][value='private']", minimum: 1
    assert_select ".filter-command-bar input[type='hidden'][name='source_type'][value='original']", minimum: 1
    assert_select ".segmented-item-active", text: I18n.t("designs.views.all")
    assert_select ".filter-chip", minimum: 5
    assert_select "a[aria-label='#{I18n.t('designs.remove_filter', filter: I18n.t('designs.views.all'))}']"
  end

  test "receptionist adds an authorized private design with multiple images" do
    sign_in users(:receptionist)

    assert_difference("Design.count") do
      post designs_path, params: {
        design: {
          title: "Hand-finished evening blouse", garment_type: "blouse", visibility: "platform_library",
          source_type: "customer_reference", source_name: "Customer fitting reference",
          tag_list: "Evening, Beadwork, evening", estimated_price: "2800", rights_confirmed: "1",
          images: [ uploaded_image("front.png"), uploaded_image("back.png") ]
        }
      }
    end

    design = Design.order(:id).last
    assert_redirected_to design_path(design)
    assert design.visibility_private?
    assert_equal [ "evening", "beadwork" ], design.tags
    assert_equal users(:receptionist), design.uploaded_by
    assert_equal 2, design.images.count
    assert design.primary_image_blob_id.present?
  end

  test "renders the new design form in instagram mode" do
    sign_in users(:manager)

    get new_design_path(source: "instagram")

    assert_response :success
    assert_select "input#design_source_url"
  end

  test "renders the design show page for an instagram reference with no uploaded image" do
    sign_in users(:manager)
    design = Design.create!(
      shop: shops(:primary), uploaded_by: users(:manager), rights_confirmed_by: users(:manager),
      rights_confirmed_at: Time.current, title: "IG design", garment_type: "blouse",
      source_type: :customer_reference, source_url: "https://www.instagram.com/p/CzAbC12DeFg/"
    )

    get design_path(design)

    assert_response :success
    assert_select "a", text: I18n.t("designs.open_on_instagram")
  end

  test "receptionist adds an instagram reference without uploading an image" do
    sign_in users(:receptionist)

    assert_difference("Design.count") do
      post designs_path, params: {
        design: {
          title: "Customer-shared blouse", garment_type: "blouse", visibility: "private",
          source_type: "customer_reference", source_url: "https://www.instagram.com/p/CzAbC12DeFg/",
          rights_confirmed: "1"
        }
      }
    end

    design = Design.order(:id).last
    assert_redirected_to design_path(design)
    assert design.instagram_reference?
    assert_not design.images.attached?
  end

  test "instagram_preview validates the url before calling the oEmbed api" do
    sign_in users(:receptionist)

    get instagram_preview_designs_path, params: { url: "https://pinterest.com/pin/12345/" }, as: :json

    assert_response :unprocessable_content
    assert_equal false, JSON.parse(response.body)["valid"]
  end

  test "instagram_preview reports a recognized link even without oEmbed credentials configured" do
    sign_in users(:receptionist)

    get instagram_preview_designs_path, params: { url: "https://www.instagram.com/p/CzAbC12DeFg/" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["valid"]
    assert_equal false, body["preview_available"]
  end

  test "workshop staff cannot use the instagram preview endpoint" do
    sign_in users(:tailor)

    get instagram_preview_designs_path, params: { url: "https://www.instagram.com/p/CzAbC12DeFg/" }, as: :json

    assert_redirected_to root_path
  end

  test "manager updates primary image and removes only a scoped attachment" do
    design = designs(:blouse_reference)
    design.images.attach(uploaded_image("first.png"), uploaded_image("second.png"))
    first, second = design.images.attachments.to_a
    design.update_column(:primary_image_blob_id, first.blob_id)
    sign_in users(:manager)

    patch design_path(design), params: {
      design: {
        title: design.title, garment_type: design.garment_type,
        remove_image_ids: [ first.id ], primary_image_attachment_id: second.id
      }
    }

    assert_redirected_to design_path(design)
    design.reload
    assert_equal [ second.id ], design.images.attachments.pluck(:id)
    assert_equal second.blob_id, design.primary_image_blob_id
  end

  test "gallery records from another shop are not discoverable" do
    sign_in users(:manager)

    get design_path(designs(:foreign_reference))

    assert_response :not_found
  end

  test "workshop staff have read-only access" do
    sign_in users(:tailor)

    get designs_path
    assert_response :success
    assert_select "a[href='#{new_design_path}']", count: 0

    assert_no_difference("Design.count") do
      post designs_path, params: {
        design: {
          title: "Unauthorized", garment_type: "blouse", rights_confirmed: "1",
          images: [ uploaded_image("unauthorized.png") ]
        }
      }
    end
    assert_redirected_to root_path
  end

  test "archiving a manual cover clears the collection reference" do
    design = designs(:blouse_reference)
    design.images.attach(uploaded_image("cover.png"))
    collection = design_collections(:bridal)
    collection.update!(cover_design: design)
    sign_in users(:manager)

    patch archive_design_path(design)

    assert_redirected_to designs_path
    assert_not design.reload.active?
    assert_nil collection.reload.cover_design
  end

  private

  def uploaded_image(name)
    fixture_file_upload(Rails.root.join("public/icon.png"), "image/png", false).tap do |file|
      file.define_singleton_method(:original_filename) { name }
    end
  end
end
