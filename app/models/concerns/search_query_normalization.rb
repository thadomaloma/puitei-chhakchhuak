module SearchQueryNormalization
  extend ActiveSupport::Concern

  SEARCH_QUERY_MAX_LENGTH = 120

  class_methods do
    def normalize_search_query(value)
      value.to_s.squish.first(SEARCH_QUERY_MAX_LENGTH)
    end
  end
end
