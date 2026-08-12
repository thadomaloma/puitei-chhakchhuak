require "test_helper"

class DesignCollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:manager)
    @collection = design_collections(:bridal)
  end

  test "tenant user browses and searches collections without foreign records" do
    get design_collections_path, params: { query: "Bridal" }

    assert_response :success
    assert_select "h1", I18n.t("design_collections.collections")
    assert_select ".filter-command-bar"
    assert_select "#collection_query_desktop[value='Bridal']"
    assert_select ".collection-filter-chip", text: /Search:\s*Bridal/
    assert_select "[data-testid='desktop-clear-collection-filters']"
    assert_select "[data-testid='collection-result-summary']",
      text: I18n.t("design_collections.result_summary_query", count: 1, query: "Bridal")
    assert_select "a[href='#{design_collection_path(@collection)}']", minimum: 1
    assert_not_includes response.body, design_collections(:foreign_collection).name
  end

  test "default index has an active navigation state, result summary and no clear action" do
    get design_collections_path

    assert_response :success
    assert_select "nav[aria-label='#{I18n.t('design_collections.studio_navigation')}'] a[aria-current='page']",
      text: I18n.t("design_collections.collections")
    assert_select "[data-testid='collection-result-summary']",
      text: I18n.t("design_collections.result_summary", count: 1)
    assert_select "[data-testid='desktop-clear-collection-filters']", count: 0
    assert_select "[data-testid='active-collection-filters']", count: 0
    assert_select ".collection-filter-chip", count: 0
  end

  test "index filters by visibility" do
    get design_collections_path, params: { visibility: "staff_visible" }

    assert_response :success
    assert_select "a[href='#{design_collection_path(@collection)}']", minimum: 1
    assert_select "button[aria-controls='collection-filter-panel']"
    assert_select "#collection-filter-panel [role='dialog'][aria-modal='true']"

    get design_collections_path, params: { visibility: "private" }
    assert_response :success
    assert_select "a[href='#{design_collection_path(@collection)}']", count: 0
    assert_select ".collection-filter-chip", text: /Visibility:\s*Private/
  end

  test "index combines search status and visibility and ignores invalid filters safely" do
    archived = create_collection("Seasonal Ceremony", visibility: :customer_shareable)
    archived.update!(description: "Winter bridal references")
    archived.archive!
    foreign = design_collections(:foreign_collection)
    foreign.update_columns(name: "Seasonal Ceremony", visibility: DesignCollection.visibilities[:customer_shareable], active: false)

    get design_collections_path, params: {
      query: "  seasonal  ", status: "archived", visibility: "customer_shareable"
    }

    assert_response :success
    assert_select "a[href='#{design_collection_path(archived)}']", minimum: 1
    assert_not_includes response.body, foreign.description
    assert_select ".collection-filter-chip", text: /Status:\s*Archived/
    assert_select ".collection-filter-chip", text: /Visibility:\s*Customer-shareable/
    assert_select "section[data-testid='active-collection-filters']" \
                  "[aria-labelledby='active-collection-filters-heading']"
    assert_select "a[aria-label='#{I18n.t('design_collections.clear_all_filters')}']" \
                  "[href='#{design_collections_path}']"

    get design_collections_path, params: { status: "not-real", visibility: "not-real" }

    assert_response :success
    assert_select ".segmented-item-active", text: I18n.t("design_collections.statuses.active")
    assert_select "a[href='#{design_collection_path(@collection)}']", minimum: 1
    assert_select "a[href='#{design_collection_path(archived)}']", count: 0
    assert_select ".collection-filter-chip", count: 0
  end

  test "mobile filters expose status and visibility and clear restores defaults" do
    get design_collections_path, params: { status: "all", visibility: "staff_visible" }

    assert_response :success
    assert_select "#collection-filter-panel select[name='status'] option[selected][value='all']"
    assert_select "#collection-filter-panel select[name='visibility'] option[selected][value='staff_visible']"
    assert_select "#collection-filter-panel a[href='#{design_collections_path}']",
      text: I18n.t("design_collections.reset_filter_options")
    assert_select "button[aria-controls='collection-filter-panel'][aria-haspopup='dialog']",
      text: I18n.t("design_collections.filters_with_count", count: 2)
    assert_select ".collection-filter-chip", text: /Status:\s*All/
    assert_select "a.button-ghost[href='#{design_collections_path}']", text: I18n.t("design_collections.clear_all")
  end

  test "mobile search clear and secondary reset preserve their respective canonical state" do
    get design_collections_path, params: {
      query: "Bridal", status: "all", visibility: "staff_visible", page: 9, unexpected: "ignored"
    }

    assert_response :success
    assert_select "button[aria-controls='collection-filter-panel'][aria-haspopup='dialog']",
      text: I18n.t("design_collections.filters_with_count", count: 2)
    assert_select "#collection-filter-panel [role='dialog'][aria-labelledby='collection-filter-title']" \
                  "[aria-describedby='collection-filter-description']"
    assert_select "a[aria-label='#{I18n.t('design_collections.clear_search')}']" do |links|
      query = Rack::Utils.parse_nested_query(URI.parse(links.first["href"]).query)
      assert_equal({ "status" => "all", "visibility" => "staff_visible" }, query)
    end
    assert_select "#collection-filter-panel a", text: I18n.t("design_collections.reset_filter_options") do |links|
      query = Rack::Utils.parse_nested_query(URI.parse(links.first["href"]).query)
      assert_equal({ "query" => "Bridal" }, query)
    end
    assert_select ".collection-filter-chip", text: /Search:\s*Bridal/
  end

  test "individual filter chip removal preserves other canonical filters and resets page" do
    17.times do |index|
      create_collection("Chip board #{index}", visibility: :staff_visible)
    end
    get design_collections_path, params: {
      query: "Chip board", status: "all", visibility: "staff_visible", page: 2
    }

    assert_response :success
    assert_select "a.collection-filter-chip-remove" \
                  "[aria-label='#{I18n.t('design_collections.remove_status_filter', status: 'All')}']" do |links|
      query = Rack::Utils.parse_nested_query(URI.parse(links.first["href"]).query)
      assert_equal "Chip board", query["query"]
      assert_equal "staff_visible", query["visibility"]
      assert_nil query["status"]
      assert_nil query["page"]
    end

    assert_select "a.collection-filter-chip-remove" \
                  "[aria-label='#{I18n.t('design_collections.remove_search_filter', query: 'Chip board')}']" do |links|
      query = Rack::Utils.parse_nested_query(URI.parse(links.first["href"]).query)
      assert_equal "all", query["status"]
      assert_equal "staff_visible", query["visibility"]
      assert_nil query["query"]
      assert_nil query["page"]
    end
  end

  test "search chip safely escapes untrusted text in the rendered index" do
    query = "<script>alert(\"atelier\")</script>"

    get design_collections_path, params: { query: query }

    assert_response :success
    assert_not_includes response.body, query
    assert_includes response.body, "&lt;script&gt;"
    assert_select ".collection-filter-chip-value", text: query
    assert_select ".collection-filter-chip-remove", count: 1 do |links|
      assert_equal I18n.t("design_collections.remove_search_filter", query: query), links.first["aria-label"]
    end
  end

  test "collection cards show metadata placeholder and authorized actions" do
    empty = create_collection("Empty Consultation Board", visibility: :private)
    empty.update!(description: "A focused placeholder collection awaiting its first approved design reference.")

    get design_collections_path

    assert_response :success
    assert_select "article" do |cards|
      empty_card = cards.find { |card| card.text.include?(empty.name) }
      assert empty_card
      assert_select empty_card, ".status-badge", text: I18n.t("design_collections.visibilities.private")
      assert_select empty_card, "p", text: /#{I18n.t('design_collections.design_count', count: 0)}/
      assert_select empty_card, "span", text: I18n.t("design_collections.cover_placeholder")
      assert_select empty_card, "p.line-clamp-2", text: /focused placeholder/
      assert_select empty_card, "a[href='#{edit_design_collection_path(empty)}']", text: I18n.t("forms.edit")
      assert_select empty_card, "a[href='#{new_design_collection_design_collection_item_path(empty)}']",
        text: I18n.t("design_collections.add_designs")
    end
  end

  test "collection card uses the optimized lazy cover variant with meaningful dimensions" do
    design = designs(:blouse_reference)
    attach_image(design)

    get design_collections_path

    assert_response :success
    assert_select "article img[loading='lazy'][width='960'][height='600'][alt*='#{@collection.name}']", minimum: 1
  end

  test "archived card communicates status and only exposes authorized archived actions" do
    @collection.archive!

    get design_collections_path, params: { status: "archived" }

    assert_response :success
    assert_select "article" do |cards|
      card = cards.find { |candidate| candidate.text.include?(@collection.name) }
      assert card
      assert_select card, ".status-badge", text: I18n.t("design_collections.statuses.archived")
      assert_select card, "a[href='#{edit_design_collection_path(@collection)}']", count: 0
      assert_select card, "a[href='#{new_design_collection_design_collection_item_path(@collection)}']", count: 0
      assert_select card, "form[action='#{restore_design_collection_path(@collection)}']"
    end
  end

  test "read-only staff see collection cards without management actions" do
    sign_in users(:cashier)

    get design_collections_path

    assert_response :success
    assert_select "a[href='#{design_collection_path(@collection)}']", minimum: 1
    assert_select "a[href='#{new_design_collection_path}']", count: 0
    assert_select "a[href='#{edit_design_collection_path(@collection)}']", count: 0
    assert_select "a[href='#{new_design_collection_design_collection_item_path(@collection)}']", count: 0
    assert_select "form[action='#{archive_design_collection_path(@collection)}']", count: 0
  end

  test "index distinguishes search and filtered empty states" do
    get design_collections_path, params: { query: "Nonexistent couture" }

    assert_response :success
    assert_select ".empty-state h3", text: I18n.t("design_collections.no_results", query: "Nonexistent couture")
    assert_select "a[href='#{design_collections_path}']", text: I18n.t("design_collections.clear_filters")

    get design_collections_path, params: { visibility: "private" }

    assert_response :success
    assert_select ".empty-state h3", text: I18n.t("design_collections.no_filtered_results")
    assert_select "a[href='#{design_collections_path}']", text: I18n.t("design_collections.clear_filters")
  end

  test "index pagination retains normalized query status and visibility" do
    17.times do |index|
      create_collection("Paged archive #{index.to_s.rjust(2, '0')}", visibility: :staff_visible).archive!
    end

    get design_collections_path, params: {
      query: "  Paged   archive  ", status: "archived", visibility: "staff_visible"
    }

    assert_response :success
    assert_select "nav[aria-label='Pagination'] a", text: I18n.t("forms.next") do |links|
      query = Rack::Utils.parse_nested_query(URI.parse(links.first["href"]).query)
      assert_equal "Paged archive", query["query"]
      assert_equal "archived", query["status"]
      assert_equal "staff_visible", query["visibility"]
      assert_equal "2", query["page"]
    end
  end

  test "collection detail combines search and garment filters within tenant and collection" do
    matching = create_design("Velvet ceremony blouse")
    add_to_collection(matching)
    outside = create_design("Velvet outside blouse")
    foreign = designs(:foreign_reference)
    foreign.update_column(:title, "Velvet foreign blouse")
    shirt = create_design("Velvet ceremony shirt", garment_type: "shirt")
    add_to_collection(shirt)

    get design_collection_path(@collection), params: { query: "  velvet ceremony ", garment_type: "blouse" }

    assert_response :success
    assert_select "a[href='#{design_path(matching)}']", minimum: 1
    assert_select "a[href='#{design_path(shirt)}']", count: 0
    assert_not_includes response.body, outside.title
    assert_not_includes response.body, foreign.title
    assert_select ".filter-chip", minimum: 2
    assert_select "[aria-live='polite']", text: I18n.t("design_collections.showing_design_count", count: 1)

    get design_collection_path(@collection), params: { garment_type: "not-real" }
    assert_response :success
    assert_select "a[href='#{design_path(matching)}']", minimum: 1
    assert_select "a[href='#{design_path(shirt)}']", minimum: 1
  end

  test "collection detail empty state clears filters" do
    get design_collection_path(@collection), params: { query: "No matching design" }

    assert_response :success
    assert_select ".empty-state h3", text: I18n.t("design_collections.no_design_results")
    assert_select "a[href='#{design_collection_path(@collection)}']", text: I18n.t("forms.clear")
  end

  test "collection detail pagination retains normalized filters" do
    25.times do |index|
      design = create_design("Paged atelier #{index.to_s.rjust(2, '0')}")
      add_to_collection(design, position: index + 2)
    end

    get design_collection_path(@collection), params: { query: "  Paged   atelier ", garment_type: "blouse" }

    assert_response :success
    assert_select "nav[aria-label='Pagination'] a", text: I18n.t("forms.next") do |links|
      query = Rack::Utils.parse_nested_query(URI.parse(links.first["href"]).query)
      assert_equal "Paged atelier", query["query"]
      assert_equal "blouse", query["garment_type"]
      assert_equal "2", query["page"]
    end
  end

  test "creates a server-scoped collection and ignores submitted ownership" do
    assert_difference("DesignCollection.count") do
      post design_collections_path, params: {
        design_collection: {
          name: "New Season", description: "Fresh references", visibility: "staff_visible",
          shop_id: shops(:foreign).id, created_by_id: users(:second_manager).id
        }
      }
    end

    collection = DesignCollection.order(:id).last
    assert_redirected_to design_collection_path(collection)
    assert_equal shops(:primary), collection.shop
    assert_equal users(:manager), collection.created_by
  end

  test "updates a tenant collection" do
    patch design_collection_path(@collection), params: {
      design_collection: { name: "Bridal Atelier", visibility: "customer_shareable" }
    }

    assert_redirected_to design_collection_path(@collection)
    assert_equal "Bridal Atelier", @collection.reload.name
    assert @collection.visibility_customer_shareable?
  end

  test "foreign collection is not discoverable or mutable" do
    foreign = design_collections(:foreign_collection)

    get design_collection_path(foreign)
    assert_response :not_found
    sign_in users(:manager)
    patch design_collection_path(foreign), params: { design_collection: { name: "Compromised" } }
    assert_response :not_found
    assert_equal "Foreign Collection", foreign.reload.name
  end

  test "cashier has read-only access" do
    sign_in users(:cashier)

    get design_collection_path(@collection)
    assert_response :success
    assert_select "a[href='#{edit_design_collection_path(@collection)}']", count: 0

    assert_no_difference("DesignCollection.count") do
      post design_collections_path, params: { design_collection: { name: "Unauthorized" } }
    end
    assert_redirected_to root_path
  end

  test "manager archives and restores a collection without deleting it" do
    assert_no_difference("DesignCollection.count") { patch archive_design_collection_path(@collection) }
    assert_not @collection.reload.active?
    assert @collection.archived_at.present?
    assert_redirected_to design_collections_path

    get design_collections_path, params: { status: "archived" }
    assert_response :success
    assert_select "a[href='#{design_collection_path(@collection)}']", minimum: 1

    patch restore_design_collection_path(@collection)
    assert @collection.reload.active?
    assert_redirected_to design_collection_path(@collection)
  end

  test "archived collection is viewable with a read-only banner" do
    @collection.archive!

    get design_collection_path(@collection)

    assert_response :success
    assert_select "[role='status']", text: /#{I18n.t('design_collections.archived_banner')}/
    assert_select "a[href='#{edit_design_collection_path(@collection)}']", count: 0
    assert_select "a[href='#{new_design_collection_design_collection_item_path(@collection)}']", count: 0
  end

  test "archived collection rejects edit and cover mutation on the server" do
    @collection.archive!

    patch design_collection_path(@collection), params: { design_collection: { name: "Changed" } }
    assert_redirected_to root_path
    assert_not_equal "Changed", @collection.reload.name

    patch set_cover_design_collection_path(@collection), params: { design_id: designs(:blouse_reference).id }
    assert_redirected_to root_path
    assert_nil @collection.reload.cover_design
  end

  test "front desk cannot archive a collection" do
    sign_in users(:receptionist)

    patch archive_design_collection_path(@collection)

    assert_redirected_to root_path
    assert @collection.reload.active?
  end

  test "manager sets a scoped collection design as the manual cover" do
    design = designs(:blouse_reference)
    attach_image(design)

    patch set_cover_design_collection_path(@collection), params: { design_id: design.id }

    assert_redirected_to design_collection_path(@collection)
    assert_equal design, @collection.reload.cover_design
    follow_redirect!
    assert_select "span", text: I18n.t("design_collections.current_cover"), minimum: 1
    assert_select "img[width='960'][height='600'][alt*='#{@collection.name}']", minimum: 1
  end

  test "manager restores automatic cover selection" do
    design = designs(:blouse_reference)
    attach_image(design)
    @collection.update!(cover_design: design)

    patch set_cover_design_collection_path(@collection)

    assert_redirected_to design_collection_path(@collection)
    assert_nil @collection.reload.cover_design
  end

  test "design outside the collection cannot be assigned as cover" do
    outside = create_design("Outside design")

    patch set_cover_design_collection_path(@collection), params: { design_id: outside.id }
    assert_response :not_found
    assert_nil @collection.reload.cover_design
  end

  test "design from another tenant cannot be assigned as cover" do
    patch set_cover_design_collection_path(@collection), params: { design_id: designs(:foreign_reference).id }
    assert_response :not_found
    assert_nil @collection.reload.cover_design
  end

  test "read-only staff cannot set a collection cover" do
    sign_in users(:tailor)

    patch set_cover_design_collection_path(@collection), params: { design_id: designs(:blouse_reference).id }

    assert_redirected_to root_path
    assert_nil @collection.reload.cover_design
  end

  private

  def create_collection(name, visibility: :private, position: 0)
    DesignCollection.create!(
      shop: shops(:primary), created_by: users(:manager), name: name,
      visibility: visibility, position: position
    )
  end

  def create_design(title, garment_type: "blouse")
    design = Design.new(
      shop: shops(:primary), uploaded_by: users(:manager), rights_confirmed_by: users(:manager),
      rights_confirmed_at: Time.current, title: title, garment_type: garment_type
    )
    attach_image(design)
    design.save!
    design
  end

  def add_to_collection(design, position: 1)
    DesignCollectionItem.create!(
      shop: shops(:primary), design_collection: @collection, design: design,
      added_by: users(:manager), position: position
    )
  end

  def attach_image(design)
    design.images.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "cover.png", content_type: "image/png")
  end
end
