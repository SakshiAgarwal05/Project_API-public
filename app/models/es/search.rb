module ES::Search
  attr_accessor :params,
                :user,
                :must,
                :must_not,
                :should,
                :filters,
                :sort,
                :original_query,
                :valid_parantheses,
                :warning

  def initialize(params = {}, user = nil)
    @warning = []
    @params = params.to_h.with_indifferent_access
    @original_query = params[:query]
    @valid_parantheses = true
    validate_query if params[:query]
    @user = user
    @must = []
    @must_not = []
    @should = []
    @filters = []
    @sort = []
    if params[:query]
      update_operators
      update_near_parameters
      update_hyphens
    end
    modify_geolocation_params
  end

  def self.my_job_json(job, obj)
    json = {
      visible_to_cs: job.visible_to_cs,
      account_managers: job.account_manager&.username,
      client_id: job.client_id,
      hiring_managers: job.hiring_manager&.username,
      hiring_watchers: job.hiring_watchers.pluck(:username),
      hiring_organization_id: job.hiring_organization_id,
      exclusive_access_end_time: job.exclusive_access_end_time,
      billing_term_id: job.billing_term_id,
      is_private: job.is_private,
      client_name: job.client ? job.client.company_name : '',
      category_id: job.category_id,
      industry_id: job.industry_id,
      category_name: job.category&.name,
      type_of_job: job.type_of_job,
    }
    case obj.class.to_s
    when 'Job'
      json.merge!({
        agency_ids: job.agency_ids,
        invited_agencies: job.current_invited_recruiters.pluck(:agency_id),
        recruiters: job.picked_by.pluck(:username),
      })
    when 'Event'
      json.merge!({
        agency_ids: ([obj.user&.agency_id] + obj.users.pluck(:agency_id)).compact,
        invited_agencies: [],
        recruiters: ([obj.user&.username] + obj.users.pluck(:username)).compact,
      })
    end
    json
  end

  private

  def validate_query
    query = params[:query]
    return unless query
    if query.match(/\(|\)/)
      if query.scan(/\(/).count != query.scan(/\)/).count
        self.valid_parantheses = false
      end
    end
  end

  def modify_geolocation_params
    if params[:location].present?
      result = Geocoder.search(params[:location])[0]
      if (result && result.postal_code.present?) || params[:distance]
        params[:distance] ||= '10'
        params.merge!(lat: result.latitude, lon: result.longitude)
      end
    end
  end

  def query(simple_query)
    q = {
      bool: {
        filter: @filters.uniq,
        must_not: @must_not,
        must: @must,
        boost: 1,
      }
    }
    if simple_query
      @warning << "Make sure operators are added correctly in order to get best results."
      @should += [
        {
          simple_query_string: {
            query: original_query,
            fields: @should.select{|sub_query| !sub_query[:query_string].nil? }[0][:query_string][:fields],
          }
        }
      ]
      @should.reject!{|sub_query| !sub_query[:query_string].nil? }
    end
    q[:bool].merge!({should: @should, minimum_should_match: 1}) if @should.any?
    q
  end

  def add_common_filters
    terms_fields.each do |param|
      next if params[param].blank?
      @filters += [{ terms: { "#{param}": params[param] } }]
    end

    terms_keywords_fields.each do |param|
      next if params[param].blank?
      @filters += [{ terms: { "#{param}.keyword": params[param] } }]
    end

    term_fields.each do |param|
      next if params[param].blank?
      @filters += [{ term: { "#{param}": params[param] } }]
    end
  end

  def add_common_should(fields=nil)
    fields ||= cross_fields
    if valid_parantheses
      @should += [
        {
          query_string: {
            query: params[:query],
            type: "cross_fields",
            fields: fields,
          }
        }
      ]
    else
      @warning << "Correct perentheses to get better results. "
      @should += [
        {
          simple_query_string: {
            query: original_query,
            fields: fields,
          }
        }
      ]
    end
  end

  def add_geo_location_filter
    if params[:lat] && params[:lon]
      params[:distance] = 1000 if params[:distance].match(/\D/)
      geo_filter = {
        distance: "#{params[:distance]}miles",
        coordinates: {
          lat: params[:lat],
          lon: params[:lon],
        },
      }

      @filters += [{ geo_distance: geo_filter }]

    elsif params[:location]
      @filters += [{
        multi_match: {
          query: params[:location],
          fields: address_fields,
          operator: "and",
        },
      }]
    end
  end

  def must_not_have_ids
    @must_not += [{ terms: { id: params[:ids_nin] } }] if params[:ids_nin].any?
  end

  def return_paginated_response(obj_class, simple_query=false)
    q = {
      from: (params.fetch(:page, 1).to_i - 1) * params.fetch(:per_page, 10).to_i,
      size: params.fetch(:per_page, 10).to_i,
      query: query(simple_query),
      _source: ['id'],
    }

    if @sort.blank? || @sort.include?('_score')
      q[:rescore] = rescore if defined?(rescore)
    else
      q[:sort] = @sort
    end
    Rails.logger.info "ES QUERY: #{obj_class} #{q.to_json}"
    response = obj_class.search(q)#.page(params.fetch(:page, 1).to_i).per(params.fetch(:per_page, 10))
    if params[:only_count]
      response.results.total
    else
      begin
        [response.records, response.results.total]
      rescue => e
        if q[:query][:bool][:should][0][:simple_query_string] || simple_query
          raise e
        end

        return_paginated_response(obj_class, true)
      end
    end
  end

  def return_aggs_response(obj_class, aggs)
    q = {
      size: 0,
      query: query(false),
      aggs: aggs,
    }
    Rails.logger.info "ES QUERY: #{obj_class} #{q.to_json}"
    obj_class.search(q).response['aggregations'].as_json
  end

  def add_autocomplete_should
    @should += [
      {
        multi_match: {
          query: params[:query],
          fields: autocomplete_fields,
          operator: "and",
        },
      },
      match_phrase_prefix: {
        message: {
          query: params[:query],
        },
      },
    ]
  end

  def update_operators
    possible_state = /(\A\s*OR)|(OR\s*\z)/
    # If OR is in begning or in last then replace it with Oregon.
    if params[:query].match(possible_state)
      params[:query].gsub!(possible_state) {|word|  word.gsub('OR', 'Oregon')}
      @warning << "Showing results for <b>#{params[:query]}</b>"
    end
    return if params[:query].blank?
    params[:query].gsub!(/(\sand\s*)|\s+\+\s+/i, ' AND ')
    params[:query].gsub!(/(\sor\s*)|\s+\\\s+/i, ' OR ')
    params[:query].gsub!(/(\snot\s*)|\s+\-\s+/i, ' NOT ')
  end

  def update_near_parameters
    return if params[:query].blank?

    near_operator_pharases = params[:query].scan(
        /(\"[\w\s]+\"\s+near\s\"+[\w\s]+\")|(\"[\w\s]+\"\s+near\s+\w+)|(\w+\s+near\s\"+[\w\s]+\")|(\w+\s+near\s+\w+)/i
      ).flatten.compact

    near_operator_pharases.each do |phrase|
      new_phrase = ["\"", phrase.gsub(/\"|near/i, ""), '"~20'].join
      params[:query].gsub!(phrase, new_phrase)
    end
  end

  def update_hyphens
    params[:query] = params[:query].split(' ').
      collect { |word| word.gsub!(/^[^\w\(\)\s\"\*]*/, '') }.
      join(' ')
  end

  def my_job_filters
    if [1, 2].include?(user.role_group)
      @filters += [{ term: { visible_to_cs: true } }]
    end

    if user.role_group == 1
      params[:account_managers].any? ? account_manager_filter : my_job_filter_internal_users
    elsif params[:recruiters].any? && user.role_group == 2
      recruiter_filter
    elsif user.role_group == 3 && !params[:skip_ho_filter]
      visible_to_ho
      hiring_manager_filter if params[:hiring_managers].any?
    end

    unless params[:my].is_true?
      case user.role_group
      when 1 then my_job_filter_internal_users
      when 2 then visible_to_recruiter
      end
    end
  end

  def account_manager_filter
    term = { terms: { account_managers: params[:account_managers] } }
    if user.super_admin? || user.admin?
      @filters += [term]
    elsif user.supervisor?
      @filters += [
        term,
        { terms: { client_id: user.my_supervisord_client_ids } }
      ]
    elsif user.account_manager?
      @filters += [
        term,
        { terms: { client_id: user.my_managed_client_ids } }
      ]
    end
  end

  def hiring_manager_filter
    return unless user.groups.exists?
    users = params[:hiring_managers] + User.joins(:groups).
      where(groups: { id: GroupsUser.where(group_id: user.group_ids).select('groups.id') }).
      distinct.pluck(:username)

    @filters += [
      {
        bool: {
          should: [
            { terms: { hiring_managers: users } },
            { terms: { hiring_watchers: users } },
          ],
          minimum_should_match: 1,
        },
      },
    ]
  end

  def visible_to_ho
    if user.groups.exists?
      if user.hiring_jobs.exists? || user.ho_jobs_watchers.exists?
        users = User.joins(:groups).
          where(groups: { id: GroupsUser.where(group_id: user.group_ids).select('groups.id') }).
          distinct.pluck(:username)
      else
        users = [user.username]
      end
      @filters += [
        {
          bool: {
            should: [
              { terms: { hiring_managers: users } },
              { terms: { hiring_watchers: users } },
            ],
            minimum_should_match: 1,
          },
        },
      ]
    else
      @filters += [{ term: { hiring_organization_id: user.hiring_organization_id } }]
    end
  end

  def my_job_filter_internal_users
    case user.primary_role
    when 'supervisor' then @filters += [{ terms: { client_id: user.my_supervisord_client_ids } }]
    when 'account manager' then @filters += [{ terms: { client_id: user.my_managed_client_ids } }]
    when 'onboarding agent' then @filters += [{ terms: { client_id: user.my_onboard_client_ids } }]
    end
  end

  def visible_to_recruiter
    @filters +=
      [{
        bool: {
          should: [
            {
              bool: {
                must: [
                  { term: { is_private: false } },
                  {
                    bool: {
                      should: [
                        # as we know private jobs can not be exclusive so is private = false is
                        # already handled and is_private = true is handled in next block
                        { range: { exclusive_access_end_time: { lt: Time.now.utc } } },
                        { terms: { billing_term_id: user.agency.exclusive_billing_term_ids } },
                        { bool: { must_not: { exists: { field: "exclusive_access_end_time" } } } },
                      ],
                      minimum_should_match: 1,
                    },
                  },
                ],
              },
            },
            {
              bool: {
                must: [
                  # when is_private is true
                  { term: { is_private: true } },
                  {
                    bool: {
                      should: [
                        { term: { agency_ids: user.agency_id } },
                        { term: { invited_agencies: user.agency_id } },
                        {
                          bool: {
                            must: [
                              { range: { exclusive_access_end_time: { gt: Time.now.utc } } },
                              {
                                terms: { billing_term_id: user.agency.exclusive_billing_term_ids },
                              },
                            ],
                          },
                        },
                      ],
                      minimum_should_match: 1,
                    },
                  },
                ],
              },
            },
          ],
          minimum_should_match: 1,
        },
      }]
  end
end
