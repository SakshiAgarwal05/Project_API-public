class ES::SearchJob
  include ES::Search

  def cross_fields
    [
      "title^30",
      "job_id^30",
      "display_job_id^30",
      "cs_job_id^30",
      "id^30",
      "client_name^25",
      "city^20",
      "state_obj^20",
      "state_obj_abbr^20",
      "postal_code^20",
      "country_obj_name^20",
      "country_obj_abbr^20",
      "job_id.autocomplete^15",
      "display_job_id.autocomplete^15",
      "cs_job_id.autocomplete^15",
      "job_id.autocomplete_ngram^10",
      "display_job_id.autocomplete_ngram^10",
      "cs_job_id.autocomplete_ngram^10",
      "summary^5",
      "responsibilities^5",
      "preferred_qualification^5",
      "minimum_qualification^5",
      "additional_detail^5",
    ]
  end

  def sharable_fields
    [
      "title^30",
      "job_id^30",
      "display_job_id^30",
      "cs_job_id^30",
      "id^30",
      "job_id.autocomplete^15",
      "display_job_id.autocomplete^15",
      "cs_job_id.autocomplete^15",
      "title.autocomplete^15",
      "job_id.autocomplete_ngram^10",
      "display_job_id.autocomplete_ngram^10",
      "cs_job_id.autocomplete_ngram^10",
      "client_name^5",
    ]
  end

  def terms_fields
    %i(
      industry_name
      id
      category_name
      location_type
      currency
      pay_period
      type_of_job
      archived_by_ids
      hiring_organization_type
      years_of_experience
      client_id
      industry_id
      category_id
    )
  end

  def terms_keywords_fields
    %i(
      client_name
    )
  end

  def term_fields
    %i(
      enable
      duration
      hiring_organization_id
    )
  end

  def autocomplete_fields
    [
      "title.autocomplete",
      "job_id.autocomplete",
      "cs_job_id.autocomplete",
      "display_job_id.autocomplete",
      "title",
      "job_id",
      "cs_job_id",
      "display_job_id"
    ]
  end

  def address_fields
    [
      'city^30',
      'country_obj_name^10',
      'country_obj_abbr^10',
      'state_obj^20',
      'state_obj_abbr^15',
      'postal_code^35',
      'address^5',
    ]
  end

  def search_jobs(aggs=nil)
    add_filters
    add_must_not
    add_must
    add_should
    add_sort
    if params[:query].present?
      UserSearch.find_or_create_by(
        user: user,
        search_tag: params[:query],
        related_to: 'Job'
      )
    end
    return_paginated_response(Job)
  end

  def aggs_search_jobs(aggs, add_filter)
    params[:skip_ho_filter] = true if user.role_group.eql?(3)
    add_filters
    add_must_not
    add_must
    self.filters += add_filter
    return_aggs_response(Job, aggs)
  end

  def autocomplete_jobs
    add_filters
    add_must_not
    add_must
    add_autocomplete_should
    @should += [{
      query_string: {
        query: params[:query],
        type: 'cross_fields',
        fields: [
          'job_id',
          'display_job_id',
          'cs_job_id',
        ],
      },
    }]
    return_paginated_response(Job)
  end

  def search_shareable_jobs
    update_params_shareable_jobs
    add_sort
    add_filter_my_shareable_jobs
    add_common_should(sharable_fields) if params[:query].present?
    return_paginated_response(Job)
  end

  private

  def add_sort
    if params[:query].blank? && params[:order_field].blank?
      @sort = [{ priority_of_status: 'desc' }, { published_at: 'desc' }]
      return
    elsif params[:order_field].blank?
      return
    end

    order_field, order = params[:order_field], (params[:order] || 'desc')
    return unless params[:order_field]

    @sort =
      case order_field
      when 'title'
        [{ "#{order_field}.keyword": order }]
      else
        ['_score']
      end
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
    if params[:not_archived].any?
      @must_not += [{ terms: { archived_by_ids: params[:not_archived] } }]
    end
  end

  def add_filters
    add_common_filters

    if [1, 2].include?(user.role_group)
      @filters += [{ term: { visible_to_cs: true } }]
    end

    if !params[:my].is_true?
      case user.role_group
      when 1 then my_job_filters
      when 2 then visible_to_recruiter
      end
    elsif user.role_group == 2 && params[:recruiters].blank?
      params[:recruiters] = [user.username]
    elsif user.role_group == 3 && params[:hiring_managers].blank?
      params[:hiring_managers] = [user.username]
    end
    if user.role_group == 1
      params[:account_managers].any? ? account_manager_filter : my_job_filters
    elsif params[:recruiters].any? && user.role_group == 2
      recruiter_filter
    elsif user.role_group == 3 && !params[:skip_ho_filter]
      visible_to_ho
      hiring_manager_filter if params[:hiring_managers].any?
    end

    unless params[:my].is_true?
      case user.role_group
      when 1 then my_job_filters
      when 2 then visible_to_recruiter
      end
    end

    salary_filter

    stage_filter if params[:stage]
    invited_filters if params[:invited]
    recommend_filter if params[:recommend]

    add_geo_location_filter
  end

  def salary_filter
    min_salary = params[:salary_min].to_i
    max_salary = params[:salary_max].to_i
    return if min_salary > max_salary

    range = {}
    range[:gte] = min_salary if min_salary.positive?
    range[:lte] = max_salary if max_salary.positive?
    unless range.blank?
      @filters += [{
        bool: {
          should: [
            { range: { pay_rate_min: range } },
            { range: { pay_rate_max: range } },
          ],
          minimum_should_match: 1,
        },
      }]
    end
  end

  def stage_filter
    @filters += [{ terms: { stage: params[:stage] } }]
  end

  def invited_filters
    @filters += [{ term: { invited_to_ids: user.id } }]
  end

  def recommend_filter
    @filters += [{ term: { recommended_to_ids: user.id } }]
  end

  def recruiter_filter
    term = { terms: { recruiters: params[:recruiters] } }
    @filters += [term]
  end

  def add_filter_my_shareable_jobs
    @filters +=
      if user.super_admin? || user.admin?
        [{ terms: { id: ShareLink.pluck(:shared_id) } }]
      elsif user.supervisor?
        [
          { terms: { client_id: user.my_supervisord_client_ids } },
          { terms: { id: ShareLink.pluck(:shared_id) } },
        ]
      elsif user.account_manager?
        [
          { terms: { client_id: user.my_managed_client_ids } },
          { terms: { id: ShareLink.pluck(:shared_id) } },
        ]
      elsif user.agency_user?
        [{ terms: { id: ShareLink.visible_to(user).pluck(:shared_id) } }]
      else
        [{ term: { id: '' } }]
      end
    @filters += [{ term: { visible_to_cs: true } }, { terms: { stage: params[:stage] } }]
  end

  def update_params_shareable_jobs
    params[:order] = 'asc' if params[:order] != 'desc'
    params[:stage] =
      if params[:shareable_type].eql?('active')
        Job::STAGES_FOR_APPLICATION
      else
        Job::STAGES_FOR_CLOSED
      end
  end

  def rescore
    {
      window_size: 50,
      query: {
        rescore_query: {
          term: {
            stage: {
              value: "Open",
              boost: 1.0,
            },
          },
        },
        query_weight: 1,
        rescore_query_weight: 100,
      },
    }
  end
end
