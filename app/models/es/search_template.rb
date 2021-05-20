class ES::SearchTemplate
  include ES::Search

  def cross_fields
    ['name^30', 'tags^25']
  end

  def terms_fields
    %i(id)
  end

  def term_fields
    %i()
  end

  def terms_keywords_fields
    %i()
  end

  def search_templates
    add_filters
    add_must
    add_should
    add_sort if params[:order_field].present?
    return_paginated_response(Template)
  end

  private

  def add_sort
    ['_score']
  end

  def add_must; end

  def add_should
    return unless params[:query]
    add_common_should
  end

  def add_filters
    add_common_filters
  end
end
