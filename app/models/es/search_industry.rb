class ES::SearchIndustry
  include ES::Search

  def autocomplete_fields
    [
      "name.autocomplete",
    ]
  end

  def search_industry
    add_must

    if params[:query].present?
      add_autocomplete_should
    end

    return_paginated_response(Industry)
  end

  private

  def add_must
    @must += [{ terms: { 'name.keyword': params[:names] } }] if params[:names].present?
  end
end
