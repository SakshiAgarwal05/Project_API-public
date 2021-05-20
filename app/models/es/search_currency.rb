class ES::SearchCurrency
  include ES::Search

  def autocomplete_fields
    [
      "name.autocomplete",
      "abbr.autocomplete",
    ]
  end

  def search_currency
    if params[:query].present?
      add_autocomplete_should
    end

    add_must
    return_paginated_response(Currency)
  end

  private

  def add_must
    if params[:abbrs].present?
      @must += [{ terms: { 'abbr.keyword': params[:abbrs] } }]
    end
  end
end