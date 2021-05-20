class ES::SearchTalent
  include ES::Search

  def cross_fields
    [
      "name^30",
      "sin^30",
      "id^30",
      "emails^40",
      "phones^40",
      "address^20",
      "city^20",
      "state_obj^20",
      "state_obj_abbr^20",
      "postal_code^20",
      "country_obj_name^20",
      "country_obj_abbr^20",
      "attachments.attachment.content^15",
      "work_authorization^15",
      "headline^5",
      "industry_name^5",
      "matching_job_title^5",
      "level_of_education^5",
      "studied_at^5",
      "previously_worked_at^5",
      "currently_working_at^5",
      "languages^4",
      "timezone.abbr^4",
      "timezone.name^2",
    ]
  end

  def terms_fields
    %i(
      industry_name
      matching_job_title
      level_of_education
      studied_at
      years_of_experience
      previously_worked_at
      currently_working_at
      id
      status
    )
  end

  def terms_keywords_fields
    []
  end

  def term_fields
    %i(
      relocate
    )
  end

  def address_fields
    [
      'city^30',
      'country_obj_name^10',
      'country_obj_abbr^10',
      'state_obj_name^20',
      'state_obj_abbr^15',
      'postal_code^35',
      'address^5',
    ]
  end

  def search_talents
    add_filters
    add_must_not
    add_must
    add_should
    add_sort if params[:order_field].present?
    if params[:query].present?
      UserSearch.find_or_create_by(
        user: user,
        search_tag: params[:query],
        related_to: 'Talent'
      )
    end
    return_paginated_response(Talent)
  end

  private

  def add_sort
    ['_score']
  end

  def add_must
    @must += [{ terms: { id: params[:ids] } }] if params[:ids].present?
  end

  def add_should
    return unless params[:query]
    add_common_should
  end

  def add_must_not
    must_not_have_ids
  end

  def add_filters
    if params[:show_available_candidates]
      params[:status] ||= []
      params[:status] += ["Available"]
    end

    params[:matching_job_title] = params[:job_title]

    add_common_filters

    add_geo_location_filter
  end
end