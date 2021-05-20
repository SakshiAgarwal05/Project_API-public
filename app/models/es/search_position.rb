module ES
  module SearchPosition
    def search_position(params = {})
      params = params.to_h

      must_match = []

      unless params[:query].blank?
        must_match.push(
          match: {
            'name.autocomplete': params[:query]
          }
        )
      end

      unless params[:names].blank?
        must_match.push(
          terms: { 'name.keyword': params[:names] }
        )
      end

      response = Position.search(
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