# View all timezone[Timezone.html]
class Api::V1:: TimezonesController < ApplicationController
  respond_to :json

  # list timezones
  # ====URL
  #   /timezones [GET]
  # ====PARAMETERS
  #   query
  #  all [true/false]
  def index
    if params[:query].present?
      @timezones, total_count = Timezone.search_timezone(params.permit(:query, :per_page, :page))
    else
      @timezones = params[:all].is_true? ? Timezone.cached_timezones : Timezone.truncated_timezones
    end
    render json: @timezones.to_json(only: [:id, :value, :abbr, :name], methods: [:dst_start_date, :dst_end_date]), status: :ok
  end
end
