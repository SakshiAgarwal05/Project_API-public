# View all degrees
class DegreesController < ApplicationController
  # list degrees
  # ====URL
  # /degrees [GET]
  # ====PARAMETERS
  # query
  # page (page number)
  # per_page (records per page)
  # names
  def index
    if params[:query].present?
      @degrees, total_count = Degree.search_degree(params.permit(:query, :per_page, :page))
    elsif params[:names].present?
      @degrees, total_count = Degree.search_degree(names: params[:names], per_page: per_page, page: page_count)
    else
      @degrees = Degree.order(popularity: :desc).page(page_count).per(per_page)
    end
    render json: @degrees.to_json(only: [:name, :id]), status: :ok
  end
end
