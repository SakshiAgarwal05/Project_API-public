module ES
  module SearchTimezone
    def search_timezone(params = {})
      params = params.to_h

      must_match = []

      unless params[:query].blank?
        must_match.push(
          match: {
            'name.autocomplete': params[:query]
          }
        )
      end

      response = Timezone.search(
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