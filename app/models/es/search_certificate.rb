module ES
  module SearchCertificate
    def search_certificate(params = {})
      params = params.to_h

      must_match = []

      unless params[:query].blank?
        must_match.push(
          match: {
            'name.autocomplete': params[:query]
          }
        )
      end

      unless params[:vendor_id].blank?
        must_match.push(
          term: {
            vendor_id: params[:vendor_id]
          }
        )
      end

      response = Certificate.search(
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