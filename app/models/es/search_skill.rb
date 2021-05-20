class ES::SearchSkill
  include ES::Search

  def autocomplete_fields
    [
      "name.autocomplete",
    ]
  end

  def search_skills
    if params[:query].present?
      add_autocomplete_should
    end
    return_paginated_response(Skill)
  end
end
