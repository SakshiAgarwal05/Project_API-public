# View all MatchingJobTitles
class MatchingJobTitlesController < ApplicationController

  # list matching job titles
  # ====URL
  #   /matching_job_titles
  # ====PARAMETERS
  def index
    render json: MatchingJobTitles.all, status: 200
  end

end
