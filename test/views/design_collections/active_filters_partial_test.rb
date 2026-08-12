require "test_helper"

class DesignCollectionsActiveFiltersPartialTest < ActionView::TestCase
  include DesignCollectionsHelper

  test "renders nothing when no active filters exist" do
    render partial: "design_collections/active_filters", locals: {
      active_filters: [],
      clear_all_path: design_collections_path,
      label: I18n.t("design_collections.active_collection_filters")
    }

    assert_empty rendered.strip
  end

  test "renders one semantic group from prepared filters and a canonical clear action" do
    filters = active_collection_filters(query: "Bridal", status: "archived", visibility: "private")

    render partial: "design_collections/active_filters", locals: {
      active_filters: filters,
      clear_all_path: design_collections_path,
      label: I18n.t("design_collections.active_collection_filters")
    }

    assert_select "section[aria-labelledby='active-collection-filters-heading']" \
                  "[data-testid='active-collection-filters']", count: 1
    assert_select "h2#active-collection-filters-heading.sr-only",
      text: I18n.t("design_collections.active_collection_filters")
    assert_select "ul > li", count: 3
    assert_select "ul > li:nth-child(1) .collection-filter-chip", text: "Search: Bridal"
    assert_select "ul > li:nth-child(2) .collection-filter-chip", text: "Status: Archived"
    assert_select "ul > li:nth-child(3) .collection-filter-chip", text: "Visibility: Private"
    assert_select "span.collection-filter-chip > .collection-filter-chip-copy + a.collection-filter-chip-remove", count: 3
    assert_select ".collection-filter-chip-copy", count: 3
    assert_select ".collection-filter-chip-label", count: 3
    assert_select ".collection-filter-chip-value", count: 3
    assert_select ".collection-filter-chip-remove svg[aria-hidden='true']", count: 3
    assert_select "a[data-testid='clear-all-collection-filters']" \
                  "[href='#{design_collections_path}']" \
                  "[aria-label='#{I18n.t('design_collections.clear_all_filters')}']",
      text: I18n.t("design_collections.clear_all")
    assert_select "ul a[data-testid='clear-all-collection-filters']", count: 0
  end

  test "escapes a search value while preserving its full accessible remove label" do
    query = "<script>alert('atelier')</script>"
    filters = active_collection_filters(query: query)

    render partial: "design_collections/active_filters", locals: {
      active_filters: filters,
      clear_all_path: design_collections_path,
      label: I18n.t("design_collections.active_collection_filters")
    }

    assert_not_includes rendered, "<script>"
    assert_includes rendered, "&lt;script&gt;"
    assert_select ".collection-filter-chip", count: 1
    assert_select ".collection-filter-chip-label", text: "Search:"
    assert_select ".collection-filter-chip-value", text: query do |values|
      assert_equal query, values.first["title"]
    end
    assert_select ".collection-filter-chip-remove", count: 1 do |links|
      assert_equal I18n.t("design_collections.remove_search_filter", query: query), links.first["aria-label"]
    end
  end

  test "search chip keeps a long value visually truncatable and its remove action practical" do
    query = "Wedding reception blouse designs with hand embroidery and a long atelier reference"
    filters = active_collection_filters(query: query, status: "archived", visibility: "private")

    render partial: "design_collections/active_filters", locals: {
      active_filters: filters,
      clear_all_path: design_collections_path,
      label: I18n.t("design_collections.active_collection_filters")
    }

    assert_select ".collection-filter-chip-search .collection-filter-chip-value[title='#{query}']", text: query
    assert_select ".collection-filter-chip-remove[href='#{design_collections_path(status: 'archived', visibility: 'private')}']" do |links|
      assert_equal I18n.t("design_collections.remove_search_filter", query: query), links.first["aria-label"]
    end
  end
end
