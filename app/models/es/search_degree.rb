class ES::SearchDegree
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

  def search_degree
    add_must if params[:names].present?

    if params[:query].present?
      add_autocomplete_should
    end

    return_paginated_response(Degree)
  end

  private

  def add_must
    @must += [{ terms: { "name.keyword": params[:names] } }]
  end
end
