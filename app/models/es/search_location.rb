module ES
  module SearchLocation
    def search_location_es(params = {})
      params = params.to_h

      must_match = []

      unless params[:query].blank?
        must_match.push(
          multi_match: {
            query: params[:query],
            fields: %w[city.autocomplete state.autocomplete country.autocomplete]
          }
        )
      end

      response = Location.search(
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