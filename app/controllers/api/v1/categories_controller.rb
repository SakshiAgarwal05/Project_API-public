# View all categories[Category.html]
class CategoriesController < ApplicationController
  respond_to :json

  # list all categories
  # ====URL
  #   /categories [GET]
  # ====PARAMETERS
  # ====Parameters
  # query
  # order_field (sort by fields name)
  # order (sort order asc/desc)
  # page (page number)
  # per_page (records per page)
  # names
  def index
    if params[:query].present?
      @categories, total_count = Category.search_category(params.permit(:query, :per_page, :page))
    elsif params[:names].present?
      @categories, total_count = Category.search_category(names: params[:names], per_page: per_page, page: page_count)
    else
      @categories = Category.sortit(params[:order_field], params[:order])
    end
  end
end
