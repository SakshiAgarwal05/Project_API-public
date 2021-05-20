module ES
  module SearchTeam
    def search_teams(params={}, user, limited_fields)
      params = params.to_h
      params[:order] = 'asc' if params[:order] != 'desc'

      must_match = []
      must_not_match = []

      unless params[:query].blank?
        query_should = [
          {
            multi_match: {
              query: params[:query],
              fields: %w[name.autocomplete company_name.autocomplete]
            }
          },
          {
            term: {
              id: params[:query]
            }
          }
        ]
        unless limited_fields
          query_should.push(
            simple_query_string: {
              query: params[:query]
            }
          )
        end
        must_match.push(
          bool: {
            should: query_should
          }
        )
      end

      unless params[:status].blank?
        if params[:status].exclude?('Enabled') && params[:status].include?('Disabled')
          must_match.push(
            term: {
              enabled: false
            }
          )
        elsif params[:status].include?('Enabled') && params[:status].exclude?('Disabled')
          must_match.push(
            term: {
              enabled: true
            }
          )
        end
      end

      unless params[:agency_id].blank?
        must_match.push(
          term: {
            agency_id: params[:agency_id]
          }
        )
      end

      unless params[:ids_nin].blank?
        must_not_match.push(
          terms: { id: params[:ids_nin] }
        )
      end

      unless params[:ids_in].blank?
        must_match.push(
          terms: { id: params[:ids_in] }
        )
      end

      # TODO(eric@crowdstaffing.com): enabled isn't in the mapping, why is it here? should it be in the mapping?
      sort =
        if %w[name enabled].include?(params[:order_field])
          sortit_es(params[:order_field], params[:order], user)
        else
          []
        end

      response = Team.search(
        query: {
          bool: {
            must: must_match,
            must_not: must_not_match
          }
        },
        sort: sort,
        _source: ['id']
      ).page(params.fetch(:page, 1).to_i).per(params.fetch(:per_page, 10))
      [response.records, response.results.total]
    end

    def sortit_es(order_field, order='asc', user)
      case order_field
      when 'name'
        [{ "#{order_field}.keyword": order }]
      when 'enabled'
        [{ "#{order_field}": order }]
      else
        ['_score']
      end
    end
  end
end
