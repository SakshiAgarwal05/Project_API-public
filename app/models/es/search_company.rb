class ES::SearchCompany
  include ES::Search

  def autocomplete_fields
    if params[:query].match?(/^\d+$/)
      [
        "name.autocomplete",
        "popularity",
      ]
    else
      ["name.autocomplete"]
    end
  end

  def search_company
    add_must

    if params[:query].present?
      add_autocomplete_should
    end
    return_paginated_response(Company)
  end

  private

  def add_must
    @must += [{ terms: { "name.keyword": params[:names] } }] if params[:names].present?
  end
end
