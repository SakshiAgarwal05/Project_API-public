# API for constants defined in talents[talent.rb]
class TalentsController < ApplicationController
  respond_to :json

  # List all <tt>Talent::BENEFITS</tt>
  # ====URL
  #   /talents/benefits [GET]
  def benefits
    render json: Talent::BENEFITS, status: 200
  end

  # List all <tt>Talent::WORK_AUTHORIZATIONS</tt>
  # ====URL
  #   /talents/work_authorizations [GET]
  def work_authorizations
    render json: Talent::WORK_AUTHORIZATIONS, status: 200
  end
end
