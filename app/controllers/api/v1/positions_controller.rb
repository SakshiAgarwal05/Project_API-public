# View all positions
class Api::V1:: PositionsController < ApplicationController

  # list positions
  # ====URL
  # /positions [GET]
  # ====PARAMETERS
  # query
  # names
  def index
    if params[:query].present?
      @positions, @total_pages = Position.search_position(params.permit(:query, :per_page, :page))
    elsif params[:names].present?
      @positions, @total_pages = Position.search_position(names: params[:names], per_page: per_page, page: page_count)
    else
      @positions = Position.all.page(page_count).per(per_page)
    end
    render json: @positions.to_json(only: [:name, :id]), status: :ok
  end

end
