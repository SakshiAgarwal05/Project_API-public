# View all countries[Country.html]
class Api::V1:: CountriesController < ApplicationController
  respond_to :json

  # list all or truncated list of countries
  # ====URL
  # /countries [GET]
  # ====PARAMETERS
  # all(true/false)
  # query
  # page (page number)
  # per_page (records per page)
  def index
    
    if params[:query].present?
      @countries, total_count = Country.search_country(params.permit(:query, :per_page, :page))
    elsif params[:usa_canada].present?
      @countries = Country.where(abbr: ['CA', 'US'])
    else
      @countries = params[:all].is_true? ? Country.cached_all_countries : Country.cached_countries
    end
    render json: @countries.to_json(only: [:name, :id, :abbr]), status: :ok
  end
end
