require "test_helper"

class DesignCollectionsHelperTest < ActionView::TestCase
  include DesignCollectionsHelper

  test "result summary distinguishes ordinary and searched collections" do
    assert_equal "3 collections", design_collection_results_summary(count: 3, query: nil)
    assert_equal "1 collection matching “bridal”", design_collection_results_summary(count: 1, query: "bridal")
  end

  test "collection filter params whitelist canonical URL state" do
    filters = collection_filter_params(
      "query" => "Bridal", "status" => "archived", "visibility" => "private",
      "page" => "7", "shop_id" => "foreign"
    )

    assert_equal({ query: "Bridal", status: "archived", visibility: "private" }, filters)
    assert_equal({ query: "Bridal" }, collection_filter_params(query: "Bridal", status: nil, visibility: ""))
    assert_equal({}, collection_filter_params(status: "active"))
  end

  test "active filters provide stable descriptive metadata and exclude the default status" do
    filters = active_collection_filters(
      query: "  Bridal   Edit  ", status: "active", visibility: "staff_visible"
    )

    assert_equal %i[query visibility], filters.pluck(:key)
    assert_equal "Bridal Edit", filters.first[:value]
    assert_equal "Bridal Edit", filters.first[:display_value]
    assert_equal "Search", filters.first[:type_label]
    assert_equal "Search: Bridal Edit", filters.first[:label]
    assert_equal design_collections_path(visibility: "staff_visible"), filters.first[:remove_path]
    assert_equal "staff_visible", filters.second[:value]
    assert_equal "Staff visible", filters.second[:display_value]
    assert_equal "Visibility", filters.second[:type_label]
    assert_equal "Visibility: Staff visible", filters.second[:label]
    assert_equal design_collections_path(query: "Bridal Edit"), filters.second[:remove_path]
  end

  test "active filters represent non-default statuses with centralized labels" do
    archived = active_collection_filters(status: "archived").sole
    all = active_collection_filters(status: "all").sole

    assert_equal({ key: :status, value: "archived", display_value: "Archived" },
      archived.slice(:key, :value, :display_value))
    assert_equal "Status: Archived", archived[:label]
    assert_equal "All", all[:display_value]
    assert_empty active_collection_filters(status: "active")
  end

  test "active filters ignore invalid values and keep their order" do
    assert_empty active_collection_filters(status: "not-real", visibility: "not-real")

    filters = active_collection_filters(query: "Bridal", status: "all", visibility: "private")
    assert_equal %i[query status visibility], filters.pluck(:key)
  end

  test "active-filter presentation performs no database queries" do
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      queries << payload[:sql] unless payload[:name] == "SCHEMA"
    end

    active_collection_filters(query: "Bridal", status: "archived", visibility: "private")

    assert_empty queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "mobile count includes only secondary filters" do
    assert_equal 0, active_collection_filter_count(query: "Bridal")
    assert_equal 1, active_collection_filter_count(query: "Bridal", status: "archived")
    assert_equal 2, active_collection_filter_count(query: "Bridal", status: "all", visibility: "private")
  end

  test "filter paths preserve only allowed remaining state and reset pagination" do
    filters = { query: "Bridal", status: "archived", visibility: "private", page: 3 }

    assert_equal design_collections_path(status: "archived", visibility: "private"),
      remove_collection_filter_path(:query, filters)
    assert_equal design_collections_path(query: "Bridal", visibility: "private"),
      remove_collection_filter_path(:status, filters)
    assert_equal design_collections_path(query: "Bridal", status: "archived"),
      remove_collection_filter_path(:visibility, filters)
    assert_equal design_collections_path(query: "Bridal"), reset_collection_secondary_filters_path(filters)
    assert_equal design_collections_path, clear_collection_filters_path
  end

  test "filter path rejects unsupported parameters" do
    assert_raises(ArgumentError) { remove_collection_filter_path(:shop_id, query: "Bridal") }
  end
end
