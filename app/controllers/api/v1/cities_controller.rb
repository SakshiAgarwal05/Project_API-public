# view all cities[city.html] cor a state[State.html] or country[Country.html].
class CitiesController < ApplicationController
  respond_to :json

  # list all or cities
  # ====URL
  #   /countries/COUNTRY_ID/states/STATE_ID/cities [GET]
  # ====PARAMETERS
  #   country_id
  #   state_id
  #   query
  def index
    params.merge!({per_page: per_page, page: page_count})
    if params[:query].present?
      cities, total = City.search_city(params.permit(:query, :state_id, :country_id, :per_page, :page))
    else
      cities = City.where(state_id: params[:state_id])
    end
    render json: cities.to_json(only: [:id, :abbr, :name]), status: 200
  end
end
