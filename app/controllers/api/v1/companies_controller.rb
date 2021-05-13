# View all companies
class CompaniesController < ApplicationController
  # list companies
  # ====URL
  # /companies [GET]
  # ====PARAMETERS
  # query
  # page (page number)
  # per_page (records per page)
  # names
  def index
    if params[:query].present? || params[:names].present?
      @companies, _total_count = Company.search_company(search_params)
    else
      @companies = Company.order(popularity: :desc).page(page_count).per(per_page)
    end
    render json: @companies.to_json(only: [:name, :id]), status: :ok
  end

  private

  def search_params
    if params[:query].present?
      params.permit(:query, :per_page, :page)
    elsif params[:names].present?
      params[:page] = page_count
      params[:per_page] = per_page
      params.permit(:names, :page, :per_page)
    end
  end
end
