module DesignCollectionsHelper
  COLLECTION_FILTER_KEYS = %i[query status visibility].freeze

  def design_collection_results_summary(count:, query:)
    key = query.present? ? "design_collections.result_summary_query" : "design_collections.result_summary"
    t(key, count: count, query: query)
  end

  def collection_filter_params(filters)
    filters = filters.to_h.symbolize_keys.slice(*COLLECTION_FILTER_KEYS)
    query = DesignCollection.normalize_search_query(filters[:query]).presence
    status = filters[:status].to_s.presence_in(DesignCollection::FILTER_STATUSES)
    visibility = filters[:visibility].to_s.presence_in(DesignCollection.visibilities.keys)
    status = nil if status == DesignCollection::DEFAULT_FILTER_STATUS

    { query: query, status: status, visibility: visibility }.compact
  end

  def active_collection_filters(filters)
    filters = collection_filter_params(filters)
    [
      if filters[:query]
        {
          key: :query,
          value: filters[:query],
          display_value: filters[:query],
          type_label: t("design_collections.filter_names.search"),
          label: t("design_collections.filter_labels.search", query: filters[:query]),
          remove_path: remove_collection_filter_path(:query, filters),
          remove_label: t("design_collections.remove_search_filter", query: filters[:query])
        }
      end,
      if filters[:status]
        status = t("design_collections.statuses.#{filters[:status]}")
        {
          key: :status,
          value: filters[:status],
          display_value: status,
          type_label: t("design_collections.filter_names.status"),
          label: t("design_collections.filter_labels.status", status: status),
          remove_path: remove_collection_filter_path(:status, filters),
          remove_label: t("design_collections.remove_status_filter", status: status)
        }
      end,
      if filters[:visibility]
        visibility = t("design_collections.visibilities.#{filters[:visibility]}")
        {
          key: :visibility,
          value: filters[:visibility],
          display_value: visibility,
          type_label: t("design_collections.filter_names.visibility"),
          label: t("design_collections.filter_labels.visibility", visibility: visibility),
          remove_path: remove_collection_filter_path(:visibility, filters),
          remove_label: t("design_collections.remove_visibility_filter", visibility: visibility)
        }
      end
    ].compact
  end

  def active_collection_filter_count(filters)
    collection_filter_params(filters).slice(:status, :visibility).size
  end

  def remove_collection_filter_path(filter, filters)
    raise ArgumentError, "unsupported collection filter" unless filter.to_sym.in?(COLLECTION_FILTER_KEYS)

    design_collections_path(collection_filter_params(filters).except(filter.to_sym))
  end

  def reset_collection_secondary_filters_path(filters)
    design_collections_path(collection_filter_params(filters).slice(:query))
  end

  def clear_collection_filters_path
    design_collections_path
  end
end
