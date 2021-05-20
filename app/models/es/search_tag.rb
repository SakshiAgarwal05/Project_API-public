module ES
  module SearchTag
    def search_tag(params = {})
      params = params.to_h

      must_match = []

      if params[:query].present?
        must_match.push(
          match: { 'name.autocomplete': params[:query] }
        )
      end

      response = Tag.search(
        query: {
          bool: { must: must_match },
        },
        _source: ['id']
      ).page(params.fetch(:page, 1).to_i).per(params.fetch(:per_page, 10))

      [response.records, response.results.total]
    end
  end
end
