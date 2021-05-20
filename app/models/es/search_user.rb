class ES::SearchUser
  include ES::Search

  def cross_fields
    [
      "name^30",
      "id^30",
      "email^40",
      "name.autocomplete^10",
      "username.autocomplete^10",
      "email.autocomplete^20",
      "contact_no^40",
      "company_name^25",
      "company_name.keyword^25",
      "company_name.autocomplete^10",
      "hiring_organization^25",
      "hiring_organization.keyword^25",
      "hiring_organization.autocomplete^10",
      "city^10",
      "city.keyword^12",
      "country_obj_name^10",
      "country_obj_name.keyword^12",
      "country_obj_abbr^12",
      "state_obj_name^10",
      "state_obj_name.keyword^12",
      "state_obj_abbr^12",
      "postal_code^15",
      "categories^20",
      "industries^20",
      "positions^20",
      "skills^18",
      "primary_role^20",
      "contact_no^30",
    ]
  end

  def terms_fields
    %i(
      role_group
      primary_role
      status
      team_ids
      group_ids
      usernames
    )
  end

  def terms_keywords_fields
    []
  end

  def term_fields
    %i(
      confirmed
      enable
      agency_id
      email
      restrict_access
      team_id
      group_id
      hiring_organization_id
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
    ]
  end

  def autocomplete_fields
    [
      "name.autocomplete^15",
      "username.autocomplete^10",
      "company_name.autocomplete^5",
      "hiring_organization.autocomplete^5",
      "email.autocomplete^20",
      "name^15",
      "username^10",
      "company_name^5",
      "hiring_organization^5",
      "email^20",
    ]
  end

  def aggs_active_users(aggs, add_filter)
    self.filters = [{ term: { role_group: 2 } }]
    self.filters += add_filter
    return_aggs_response(User, aggs)
  end

  def search_users
    add_filters
    visibility_filter
    add_must_not
    add_must
    add_should
    add_sort if params[:order_field].present?
    if params[:query].present?
      UserSearch.find_or_create_by(
        user: user,
        search_tag: params[:query],
        related_to: 'User'
      )
    end
    return_paginated_response(User)
  end

  def autocomplete_users
    add_filters
    visibility_filter
    add_must_not
    add_must
    add_autocomplete_should
    if params[:query].present?
      UserSearch.find_or_create_by(
        user: user,
        search_tag: params[:query],
        related_to: 'User'
      )
    end
    return_paginated_response(User)
  end

  def autocomplete_users_with_admins(parent)
    add_filters
    visible_to_with_admins_es(parent)
    add_must_not
    add_must
    add_autocomplete_should
    @should += [{
      query_string: {
        query: params[:query],
        type: "cross_fields",
        fields: [
          "job_id",
          "display_job_id",
          "cs_job_id"
        ],
      }
    }]
    return_paginated_response(User)
  end

  def autocomplete_internal_users
    params[:ids_nin] ||= []
    if params[:except_client].present?
      params[:ids_nin] += Assignable.for_client(params[:except_client]).
        distinct(:user_id).pluck(:user_id)
    end
    params[:ids_nin] << params[:except_user_id] if params[:except_user_id].present?

    add_filters
    visible_admins
    add_must_not
    add_must
    add_autocomplete_should
    if params[:query].present?
      UserSearch.find_or_create_by(
        user: user,
        search_tag: params[:query],
        related_to: 'User'
      )
    end
    return_paginated_response(User)
  end

  def search_user_contacts
    filters, must_match, must_not_match, should_match = [], [], [], []

    if params[:term].present?
      query_should = [
        {
          multi_match: {
            query: params[:term],
            fields: %w(
              first_name.autocomplete^7
              last_name.autocomplete^6
              username.autocomplete^6
              emails^10
              email^10
            ),
          },
        },
        {
          term: {
            id: params[:term],
          },
        },
      ]

      query_should.push( simple_query_string: { query: params[:term] } )

      must_match.push( bool: { should: query_should } )
    end

    must_match.push(term: { confirmed: true } )
    must_match.push(term: { locked: false })
    filters.push(term: { status: 'Active' })

    if user.agency_user?
      must_match.push(
        bool: {
          should: [
            { term: { agency_id: user.agency_id } },
            { term: { role_group: 1 } }
          ]
        }
      )
    elsif user.hiring_org_user?
      must_match.push(
        bool: {
          should: [
            { term: { hiring_organization_id: user.hiring_organization_id } },
            { term: { role_group: 1 } }
          ]
        }
      )
    elsif user.internal_user?
      must_match.push(terms: { role_group: [1,2,3] })
    end

    must_match.push(term: { restrict_access: true }) if user.restrict_access

    bool = {
      must: must_match,
      should: should_match,
      must_not: must_not_match,
      filter: filters
    }

    q = {
      from: (params.fetch(:page, 1).to_i - 1) * params.fetch(:per_page, 10).to_i,
      size: params.fetch(:per_page, 10).to_i,
      query: { bool: bool },
      _source: ['id']
    }

    response = User.search(q)

    return [response.records, response.results.total]
  end

  private

  def add_sort
    return unless params[:order_field]
    order_field, order = params[:order_field], (params[:order] || 'desc')
    @sort = case order_field
      when 'first_name'
        [{ "name.keyword": order }]
      when 'current_sign_in_at'
        [{ "last_sign_in_at": order }]
      when  'confirmed_at'
        [{ "#{order_field}": order }]
      when 'email', 'contact_no',
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
  end

  def add_filters
    add_common_filters
    if params[:job_id].present?
      job = Job.find(params[:job_id])
      if params[:csmm_match].is_true?
        params[:ids_nin] ||= []
        params[:ids_nin] += job.affiliates.invited_or_saved.pluck(:user_id).uniq
        # @filters += [ {terms: { id: User.csmm_recruiters_and_scores(job, user).pluck(:id) }} ]
      end
      if params[:invited_recruiters].is_true?
        @filters += [ {terms: { id: User.invited_distributed_restricted_jobs(job).visible_to(user).pluck(:user_id) }} ]
      end
      if params[:saved_recruiters].is_true?
        @filters += [ {terms: { id: job.affiliates.saved.select(:user_id).distinct.pluck(:user_id) }} ]
      end
    end

    add_geo_location_filter
  end

  def visibility_filter
    # @filters += [{ term: { id: user.id } }] if Role::COMMON_USED_ROLES.include?(user.primary_role)
    if user.role_group == 2
      @filters += [{ term: { agency_id: user.agency_id } }]
      if user.agency_owner_admin?
        # do nothing
      elsif user.teams.any?
        @filters += [{ term: { teams: user.teams.pluck(:name) } }]
        @filters += [{ term: { primary_role: 'team member' } }] if user.team_member?
      else
        @filters += [{ term: { id: user.id } }]
      end
    elsif user.role_group == 1

    elsif user.role_group == 3
      @filters += [{ term: { hiring_organization_id: user.hiring_organization_id } }]
      if user.enterprise_owner_admin?
        # do nothing
      elsif user.groups.any?
        @filters += [{ term: { groups: user.groups.pluck(:name) } }]
        @filters += [{ term: { primary_role: 'enterprise member' } }] if user.team_member?
      else
        @filters += [{ term: { id: user.id } }]
      end
    else
      @filters += [{ term: { id: user.id } }]
    end
  end

  def visible_to_with_admins_es(parent)
    unless Role::COMMON_USED_ROLES.include?(user.primary_role) || user.agency_user? || user.hiring_org_user?
      @filters += [{ term: { id: '' } }]
      return
    end
    default_users = []
    case parent.class.to_s
    when 'TalentsJob'
      job = parent.job
      client = parent.client
      default_users += [parent.user_id] + job.notifiers

      if params[:note].present?
        default_users += parent.user.find_admins.verified.pluck(:id) if parent.agency.present?
      else
        default_users += parent.agency.users.verified.pluck(:id) if parent.agency.present?
      end

      if Role::COMMON_USED_ROLES.include?(user.primary_role)
        default_users += User.super_admins.pluck(:id) + User.admins.pluck(:id)
      end

      default_users += client.account_managers.pluck(:user_id) +
        client.supervisors.pluck(:user_id) +
        client.onboarding_agents.pluck(:user_id)

    when 'Job'
      job = parent
      agency_users = []

      if user.team_member? || user.team_admin?
        agency_users += user.my_team_users.pluck(:id) + user.agency.users.agency_admins.pluck(:id)
      elsif user.agency_owner_admin?
        agency_users += user.agency.user_ids
      elsif user.internal_user?
        agency_users += parent.picked_by_ids
      end

      if user.hiring_org_user?
        default_users = job.picked_by_ids + job.notifiers
      else
        default_users += agency_users + job.account_manager_ids + job.onboarding_agent_ids + job.supervisor_ids
        default_users += User.super_admins.pluck(:id) + User.admins.pluck(:id) if Role::COMMON_USED_ROLES.include?(user.primary_role)
      end
    end
    @filters += [ { terms: { id: default_users.flatten.compact.uniq } } ] if default_users.any?
  end

  def visible_admins
    if params[:except_job].present?
      job = Job.find params[:except_job]
      case params[:role]
      when 'supervisor'
        @filters += [{ terms: { id: job.supervisor_ids } }]
      when 'account manager'
        @filters += [{ terms: { id: job.account_manager_ids } }]
      when 'onboarding_agent'
        @filters += [{ terms: { id: job.onboarding_agent_ids } }]
      end
    end
  end
end
