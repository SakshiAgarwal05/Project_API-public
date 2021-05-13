class ES::SearchCategory
  include ES::Search

  def autocomplete_fields
    ["name.autocomplete"]
  end

  def search_category
    add_must if params[:names].present?

    if params[:query].present?
      add_autocomplete_should
    end

    return_paginated_response(Category)
  end

  private

  def add_must
    @must += [{ terms: { "name.keyword": params[:names] } }]
  end
end
