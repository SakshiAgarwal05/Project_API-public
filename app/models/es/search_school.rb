module ES
  module SearchSchool
    def search_school(params = {})
      params = params.to_h

      must_match = []

      unless params[:query].blank?
        fields =
          if params[:query].match?(/^\d+$/)
            %w[name.autocomplete popularity]
          else
            %w[name.autocomplete]
          end
        must_match.push(
          multi_match: {
            query: params[:query],
            fields: fields
          }
        )
      end

      unless params[:names].blank?
        must_match.push(
          terms: { 'name.keyword': params[:names] }
        )
      end

      response = School.search(
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