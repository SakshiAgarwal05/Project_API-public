module ES
  module SearchState
    def search_state(params = {})
      params = params.to_h

      must_match = []

      unless params[:query].blank?
        must_match.push(
          multi_match: {
            query: params[:query],
            fields: %w[name.autocomplete abbr.autocomplete]
          }
        )
      end

      unless params[:country_id].blank?
        must_match.push(
          term: {
            country_id: params[:country_id]
          }
        )
      end

      response = State.search(
        query: {
          bool: {
            must: must_match
          }
        },
        _source: ['id']
      ).page(params.fetch(:page, 1).to_i).per(params.fetch(:per_page, 10))

      [response.records, response.results.total]
    end
  end
end