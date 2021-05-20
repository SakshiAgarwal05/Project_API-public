class Api::V1:: LocationsController < ApplicationController
  # list locations
  # ====URL
  # /locations [GET]
  # ====PARAMETERS
  # query
  # page (page number)
  # per_page (records per page)
  def index
    if params[:query].present?
      @locations, total_count = Location.search_location(
        query: params[:query], per_page: per_page, page: page_count)
    else
      render json: {error: "Query is incorrect."}, status: 422
    end
  end
end
