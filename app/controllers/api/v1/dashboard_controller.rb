# Not required.
require 'net/http'
require 'uri'
class Api::V1:: DashboardController < ApplicationController
  respond_to :json

  def index
  	
    render json: {
    	fe_host: FE_HOST,
    	talentapp: JOBS_FE_HOST,
    	branch: GIT_BRANCH,
    	last_deployed: GIT_LOG.split("\n")
    }, status: :ok
  end
end
