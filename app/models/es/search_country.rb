module ES
  module SearchCountry
    def search_country(params = {})
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

      response = Country.search(
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