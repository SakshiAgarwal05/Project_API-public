# View all schools
class SchoolsController < ApplicationController

  # list schools
  # ====URL
  # /schools [GET]
  # ====PARAMETERS
  # query
  # page (page number)
  # per_page (records per page)
  # names
  def index
    if params[:query].present?
      @schools, total_count = School.search_school(params.permit(:query, :per_page, :page))
    elsif params[:names].present?
      @schools, total_count = School.search_school(names: params[:names], per_page: per_page, page: page_count)
    else
      @schools = School.order(popularity: :desc).page(page_count).per(per_page)
    end
    render json: @schools.to_json(only: [:name, :id]), status: :ok
  end
end
