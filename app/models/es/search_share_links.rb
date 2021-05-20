class ES::SearchShareLinks
  include ES::Search

  def cross_fields
    []
  end

  def terms_fields
    %i(
      client_id
      industry_id
      category_id
    )
  end

  def terms_keywords_fields
    %i()
  end

  def term_fields
    %i(hiring_organization_id)
  end

  def aggs_search_share_links(aggs, add_filter)
    add_filters
    add_must_not
    add_must
    self.filters += add_filter
    return_aggs_response(ShareLink, aggs)
  end

  private

  def add_must
  end

  def add_must_not
    must_not_have_ids
  end

  def add_filters
    add_common_filters
  end

  def rescore
  end
end
