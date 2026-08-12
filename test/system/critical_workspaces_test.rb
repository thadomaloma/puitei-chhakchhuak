require "application_system_test_case"

class CriticalWorkspacesTest < ApplicationSystemTestCase
  CORE_PATHS = %w[
    / /customers /measurements /orders /production /inventory /deliveries
    /payments /expenses /reports /staff /payment_setting
  ].freeze

  test "owner can reach every core workspace on desktop" do
    page.current_window.resize_to(1440, 1000)
    sign_in_as users(:owner)

    CORE_PATHS.each do |path|
      visit path
      assert_current_path path
      assert_responsive_document
      if path == "/"
        priorities = find("#today-priorities-title").ancestor("section")
        dashboard_grid = priorities.ancestor("div.grid")
        assert_equal 2, page.evaluate_script("getComputedStyle(arguments[0]).gridTemplateColumns.split(' ').length", dashboard_grid)
      end
      assert_selector "progress.progress-bar", minimum: 1, visible: :all if path == "/reports"
    end
  end

  test "mobile workspaces do not overflow and More is an accessible dialog" do
    sign_in_as users(:owner)
    page.current_window.resize_to(390, 844)

    visit root_path
    assert_responsive_document
    dashboard_order = page.evaluate_script(<<~JAVASCRIPT)
      ["today-priorities-title", "team-capacity-title", "recent-orders-title", "production-progress-title"].map((id) => {
        return document.getElementById(id).closest("section").getBoundingClientRect().top
      })
    JAVASCRIPT
    assert_equal dashboard_order.sort, dashboard_order

    %w[/measurements /orders /reports /staff].each do |path|
      visit path
      assert_responsive_document
    end

    click_button I18n.t("navigation.more")
    assert_selector "#mobile-more-menu[aria-hidden='false'] [role='dialog'][aria-modal='true']"
    assert_selector "#mobile-more-menu a", text: I18n.t("navigation.measurements")
    assert_selector "#mobile-more-menu a", text: I18n.t("navigation.reports")
    assert_selector "#mobile-more-menu a[href='#{payment_setting_path}']", text: I18n.t("navigation.payment_settings")
    assert_no_selector "#mobile-more-menu a[href='#{subscription_path}']"
  end

  test "mobile collection filters and collection search remain accessible" do
    archived = DesignCollection.create!(
      shop: shops(:primary), created_by: users(:owner), name: "Mobile Archived Board",
      visibility: :staff_visible
    )
    archived.archive!
    sign_in_as users(:owner)
    page.current_window.resize_to(1440, 1000)
    visit design_collections_path
    assert_equal 4, page.evaluate_script("getComputedStyle(document.querySelector('.collection-grid')).gridTemplateColumns.split(' ').length")

    page.current_window.resize_to(390, 844)
    visit design_collections_path

    assert_responsive_document
    assert_selector "#collection-filter-button[aria-haspopup='dialog'][aria-expanded='false']"
    click_button I18n.t("design_collections.filters")
    assert_selector "#collection-filter-panel[aria-hidden='false'] [role='dialog'][aria-modal='true']"
    page.send_keys(:escape)
    assert_selector "#collection-filter-panel[aria-hidden='true']", visible: :all
    assert_equal "collection-filter-button", page.evaluate_script("document.activeElement.id")

    click_button I18n.t("design_collections.filters")
    select I18n.t("design_collections.statuses.archived"), from: I18n.t("design_collections.status_filter")
    click_button I18n.t("design_collections.apply_filters")
    assert_button I18n.t("design_collections.filters_with_count", count: 1)
    assert_selector ".collection-filter-chip", text: I18n.t("design_collections.statuses.archived")
    assert_text archived.name

    click_button I18n.t("design_collections.filters_with_count", count: 1)
    assert_field I18n.t("design_collections.status_filter"), with: "archived"
    select I18n.t("design_collections.visibilities.staff_visible"), from: I18n.t("design_collections.visibility_filter")
    click_button I18n.t("design_collections.apply_filters")

    assert_button I18n.t("design_collections.filters_with_count", count: 2)
    assert_selector ".collection-filter-chip", text: I18n.t("design_collections.statuses.archived")
    assert_selector ".collection-filter-chip", text: I18n.t("design_collections.visibilities.staff_visible")
    assert_responsive_document

    find("#collection_query_mobile").fill_in with: "Mobile Archived"
    click_button I18n.t("design_collections.search")
    assert_selector ".collection-filter-chip", count: 3
    assert_selector ".collection-filter-chip", text: /Search:\s*Mobile Archived/
    assert_button I18n.t("design_collections.filters_with_count", count: 2)

    find("a[aria-label='#{I18n.t('design_collections.remove_search_filter', query: 'Mobile Archived')}']").click
    assert_no_selector ".collection-filter-chip", text: /Search:/
    assert_selector ".collection-filter-chip", text: I18n.t("design_collections.statuses.archived")
    assert_selector ".collection-filter-chip", text: I18n.t("design_collections.visibilities.staff_visible")

    page.go_back
    assert_selector ".collection-filter-chip", text: /Search:\s*Mobile Archived/
    find("a[aria-label='#{I18n.t('design_collections.remove_search_filter', query: 'Mobile Archived')}']").click

    find("a[aria-label='#{I18n.t('design_collections.remove_status_filter', status: 'Archived')}']").click
    assert_no_selector "a[aria-label='#{I18n.t('design_collections.remove_status_filter', status: 'Archived')}']"
    assert_selector ".collection-filter-chip", text: I18n.t("design_collections.visibilities.staff_visible")
    assert_button I18n.t("design_collections.filters_with_count", count: 1)

    find("a.button-ghost", text: I18n.t("forms.clear")).click
    assert_current_path design_collections_path

    visit design_collections_path(query: "No matching collection")
    assert_current_path design_collections_path(query: "No matching collection")
    assert_selector ".empty-state", text: I18n.t("design_collections.no_results", query: "No matching collection")
    click_link I18n.t("design_collections.clear_filters")
    assert_current_path design_collections_path

    visit design_collection_path(design_collections(:bridal))
    find("input[name='query']").fill_in with: "Pearl"
    select I18n.t("designs.all_garments"), from: I18n.t("designs.garment_type")
    click_button I18n.t("designs.apply_filters")
    assert_selector ".filter-chip", text: "Pearl"
    assert_selector "a[href='#{design_path(designs(:blouse_reference))}']"
    assert_responsive_document
  end

  test "long collection search chip stays usable at mobile and desktop widths" do
    query = "Wedding reception blouse designs with hand embroidery and a long atelier reference"
    sign_in_as users(:owner)

    [ 375, 390, 1024 ].each do |width|
      page.current_window.resize_to(width, 900)
      visit design_collections_path(query: query, status: "archived", visibility: "private")

      assert_responsive_document
      assert_selector ".collection-filter-chip-search .collection-filter-chip-label", text: "Search:"
      assert_selector ".collection-filter-chip-search .collection-filter-chip-value[title='#{query}']", text: query
      assert_selector "a.collection-filter-chip-remove[aria-label='#{I18n.t('design_collections.remove_search_filter', query: query)}']"

      chip_metrics = page.evaluate_script(<<~JAVASCRIPT)
        (() => {
          const value = document.querySelector(".collection-filter-chip-search .collection-filter-chip-value")
          const remove = document.querySelector(".collection-filter-chip-search .collection-filter-chip-remove")
          const neutralChip = document.querySelector(".collection-filter-chip-neutral")
          const neutralLabel = neutralChip.querySelector(".collection-filter-chip-label")
          const neutralValue = neutralChip.querySelector(".collection-filter-chip-value")
          const chipList = document.querySelector("[data-testid='active-collection-filters'] ul")
          const clearAll = document.querySelector("[data-testid='clear-all-collection-filters']")
          const valueStyle = getComputedStyle(value)
          const neutralStyle = getComputedStyle(neutralChip)
          return {
            valueClientWidth: value.clientWidth,
            valueScrollWidth: value.scrollWidth,
            textOverflow: valueStyle.textOverflow,
            whiteSpace: valueStyle.whiteSpace,
            chipBorderStyle: neutralStyle.borderStyle,
            chipBackground: neutralStyle.backgroundColor,
            labelColor: getComputedStyle(neutralLabel).color,
            valueColor: getComputedStyle(neutralValue).color,
            clearAllBelowChips: clearAll.getBoundingClientRect().top >= chipList.getBoundingClientRect().bottom,
            removeWidth: remove.getBoundingClientRect().width,
            removeHeight: remove.getBoundingClientRect().height
          }
        })()
      JAVASCRIPT

      assert_operator chip_metrics.fetch("valueScrollWidth"), :>, chip_metrics.fetch("valueClientWidth")
      assert_equal "ellipsis", chip_metrics.fetch("textOverflow")
      assert_equal "nowrap", chip_metrics.fetch("whiteSpace")
      assert_equal "solid", chip_metrics.fetch("chipBorderStyle")
      assert_not_equal "rgba(0, 0, 0, 0)", chip_metrics.fetch("chipBackground")
      assert_not_equal chip_metrics.fetch("labelColor"), chip_metrics.fetch("valueColor")
      assert chip_metrics.fetch("clearAllBelowChips")
      assert_operator chip_metrics.fetch("removeWidth"), :>=, 32
      assert_operator chip_metrics.fetch("removeHeight"), :>=, 32
    end
  end
end
