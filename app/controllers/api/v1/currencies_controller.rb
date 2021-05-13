# View currency[Currency.html]
class CurrenciesController < ApplicationController
  respond_to :json

  # list positions
  # ====URL
  # /currencies [GET]
  # ====PARAMETERS
  # query
  # abbrs
  def index
    if params[:query].present?
      @currencies, total_count = Currency.search_currency(params.permit(:query, :per_page, :page))
    elsif params[:abbrs].present?
      @currencies, total_count = Currency.search_currency(abbrs: params[:abbrs], per_page: per_page, page: page_count)
    elsif params[:country_id]
      @currencies = Country.find(params[:country_id]).currencies rescue []
    else
      @currencies = Currency.all
    end
    render json: @currencies.to_json(only: [:name, :id, :abbr]), status: :ok
  end
end
