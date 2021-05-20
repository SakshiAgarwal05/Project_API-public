# List all states[State.html]
class Api::V1:: StatesController < ApplicationController
  respond_to :json

  # list states
  # ====URL
  #   /countries/COUNTRY_ID/states [GET]
  # ====PARAMETERS
  #   country_id
  #   query
  def index
    params.merge!({per_page: per_page, page: page_count})
    if params[:query].present?
      states, total = State.search_state(params.permit(:query, :country_id, :per_page, :page))
    else
      states = State.where(country_id: params[:country_id])
    end
    render json: states.to_json(only: [:id, :abbr, :name]), status: 200
  end
end
