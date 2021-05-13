# view all industries[Industry.html]
class IndustriesController < ApplicationController

  # list positions
  # ====URL
  # /industries [GET]
  # ====PARAMETERS
  # query
  # order_field (sort by fields name)
  # order (sort order asc/desc)
  # page (page number)
  # per_page (records per page)
  def index
    if params[:query].present? || params[:names].present?
      @industries, _total_count = Industry.search_industry(search_params)
    else
      @industries = Industry.cached_industries
    end
  end

  private

  def search_params
    params[:per_page] = per_page
    params[:page] = page_count

    if params[:query].present?
      params.permit(:query, :per_page, :page)
    elsif params[:names].present?
      params.permit(:names, :per_page, :page)
    end
  end
end
