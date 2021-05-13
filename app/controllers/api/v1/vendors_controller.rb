# View all vendors who provide certificates
class VendorsController < ApplicationController

  # list all list of vendors
  # ====URL
  #   /vendors [GET]
  # ====PARAMETERS
  def index
    if params[:query].present?
      @vendors, total_count = Vendor.search_vendor(params.permit(:query, :per_page, :page))
    else
      @vendors = Vendor.cached_vendors
    end
    render json: @vendors.to_json(only: [:name, :id]), status: :ok
  end
end
