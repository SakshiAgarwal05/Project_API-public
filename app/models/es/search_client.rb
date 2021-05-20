class ES::SearchClient
  include ES::Search

  def cross_fields
    [
      "company_name^30",
      "id^30",
      "city^20",
      "state_obj^20",
      "state_obj_abbr^20",
      "postal_code^20",
      "country_obj_name^20",
      "country_obj_abbr^20",
      "company_name.autocomplete^15",
      "about^5",
      "website^20",
      "industry_name^5",
    ]
  end

  def terms_fields
    %i(
      industry_name
      id
      status
      saved_by_ids
      account_manager_ids
      supervisor_ids
      onboarding_agent_ids
    )
  end

  def terms_keywords_fields
    %i(
    )
  end

  def term_fields
    %i(
      enable
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
      "company_name.autocomplete",
    ]
  end

  def search_clients
    add_filters
    add_must_not
    add_must
    add_should
    add_sort
    if params[:query].present?
      UserSearch.find_or_create_by(
        user: user,
        search_tag: params[:query],
        related_to: 'Client'
      )
    end
    return_paginated_response(Client)
  end

  def autocomplete_clients
    add_filters
    add_must_not
    add_must
    add_autocomplete_should
    @should += [
      {
        query_string: {
          query: params[:query],
          type: "cross_fields",
          fields: [
            "company_name.autocomplete^30",
            "company_name^20",
          ],
        },
      },
    ]
    return_paginated_response(Client)
  end

  private

  def add_sort
    return unless params[:order_field]
    order_field, order = params[:order_field], (params[:order] || 'desc')

    @sort = case order_field
            when 'company_name'
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
    my_clients
    add_common_filters
    add_geo_location_filter
  end

  def my_clients
    if params[:my].is_true?
      case user.role_group
      when 1
        case user.primary_role
        when 'account manager'
          params[:account_manager_ids] = [user.id]
        when 'supervisor'
          params[:supervisor_ids] = [user.id]
        when 'onboarding agent'
          params[:onboarding_agent_ids] = [user.id]
        end
      when 2
        params[:saved_by_ids] = [user.id]
      end
    end
    params[:status] = %w(New Enabled) if user.role_group == 2
  end
end
