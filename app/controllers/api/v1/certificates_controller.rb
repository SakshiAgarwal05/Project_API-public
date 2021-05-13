# List all certificates
class CertificatesController < ApplicationController

  # list certificates
  # ====URL
  #   /vendors/VENDOR_ID/certificates [GET]
  # ====PARAMETERS
  #   vendor_id
  #   query
  def index
    vendor = Vendor.find(params[:vendor_id])
    if vendor
      if params[:query]
        params[:page] = page_count
        params[:per_page] = per_page
        @certificates, @total_count = Certificate.search_teams(
          params.permit(:query, :page, :per_page, :vendor_id), current_user, true)
      else
        @certificates = vendor.certificates.where.not(name: "[]")
      end
    else
      render json: {error: "vendor not found"}, status: 422
    end
  end
end
