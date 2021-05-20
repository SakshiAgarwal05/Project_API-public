class ES::SearchTalentsJob
  include ES::Search

  def cross_fields
    [
      "name^30",
      "emails^30",
      "phones^30",
      "job_title^30",
      "job_job_id^30",
      "display_job_id^30",
      "cs_job_id^30",
      "job_id^30",
      "tags^25",
      "client_name^25",
      "recruiter_name^25",
      "recruiter_username^25",
      "recruiter_agency_name^25",
      "talent_city^20",
      "talent_state_obj.name^20",
      "talent_state_obj.abbr^20",
      "talent_postal_code^20",
      "talent_country_obj.name^20",
      "talent_country_obj.abbr^20",
      "work_authorization^20",
      # "job_city^20",
      # "job_state_obj.name^20",
      # "job_state_obj.abbr^20",
      # "job_postal_code^20",
      # "job_country_obj.name^20",
      # "job_country_obj.abbr^20",
      "talent_address^5",
      "category_name^5",
      "job_job_id.autocomplete^2",
      "display_job_id.autocomplete^2",
      "cs_job_id.autocomplete^2",
      "job_job_id.autocomplete_ngram^2",
      "display_job_id.autocomplete_ngram^2",
      "cs_job_id.autocomplete_ngram^2",
      "type_of_job"
    ]
  end

  def terms_fields
    %i(
    )
  end

  def terms_keywords_fields
    %i(
    )
  end

  def term_fields
    %i(
      hiring_organization_id
    )
  end

  def search_talents_jobs
    add_filters
    add_must_not
    add_must
    add_should
    add_sort if params[:order_field].present?
    return_paginated_response(TalentsJob)
  end

  def aggs_search_talents_jobs(aggs, add_filter)
    params[:skip_ho_filter] = true if user.role_group.eql?(3)
    add_common_filters
    my_talents_job_filters
    self.filters += add_filter
    return_aggs_response(TalentsJob, aggs)
  end

  private

  def add_sort
    unless params[:order_field]
      order_field, order = 'updated_at', 'desc' if params[:query].blank?
    end
    order_field, order = params[:order_field], (params[:order] || 'desc')

    @sort = case order_field
      when 'first_name'
        [{ "name.keyword": order }]
      when 'title'
        [{ "job_title.keyword": order }]
      when 'client_name'
        [{ "#{order_field}.keyword": order }]
      when 'stage', 'updated_at'
        [{ "#{order_field}": order }]
      else
        ['_score']
      end
  end

  def add_must
  end

  def add_should
    return unless params[:query]
    add_common_should
  end

  def add_must_not
    must_not_have_ids
  end

  def add_filters
    add_common_filters
    my_talents_job_filters
    if params[:status].any?
      if params[:status].include?('Interview')
        @filters += [
          {
            bool: {
              should: [
                { terms: { stage: params[:status] } },
                { range: { sort_order: { gte: 2.0, lte: 2.9 } } },
              ],
              minimum_should_match: 1,
            },
          },
        ]
      else
        @filters += [{ terms: { stage: params[:status] } }]
      end
    end

    @filters += [
      { terms: { job_stage: ['Open', 'On Hold'] } },
      { term: { withdrawn: false } },
      { term: { rejected: params[:disqualified].is_true? } }
    ]
  end

  def my_talents_job_filters
    case user.primary_role
    when 'account manager'
      @filters += [{ terms: { client_id: user.my_managed_client_ids } }]
    when 'supervisor'
      @filters += [{ terms: { client_id: user.my_supervisord_client_ids } }]
    when 'onboarding agent'
      @filters += [{ terms: { client_id: user.my_onboard_client_ids } }]
    end

    if user.internal_user? && params[:account_managers].any?
      @filters += [{ terms: { account_managers: params[:account_managers] } }]
    end

    if user.agency_user?
      @filters +=
        if params[:recruiters].any?
          [{ terms: { "recruiter_username.keyword": params[:recruiters] } }]
        else
          case user.primary_role
          when 'agency owner', 'agency admin'
            [{ term: { "recruiter_agency_name.keyword": user.agency&.company_name } }]
          when 'team admin'
            [{ terms: { "recruiter_username.keyword": user.my_team_users.pluck(:username) } }]
          when 'team member'
            [{ terms: {
              'recruiter_username.keyword': user.my_team_users.team_members.pluck(:username),
            } }]
          end
        end
    end
    visible_to_ho if user.hiring_org_user?
  end

  def rescore
    {
      window_size: 50,
      query: {
        rescore_query: {
          term: {
            job_stage: {
              value: "Open",
              boost: 1.0
            }
          }
        },
       query_weight: 1,
       rescore_query_weight: 100
      }
   }
  end

end
