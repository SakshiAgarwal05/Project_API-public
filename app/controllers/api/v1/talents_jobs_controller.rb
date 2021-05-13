class TalentsJobsController < ApplicationController
  skip_load_and_authorize_resource
  before_action :find_talents_job, only: :show

  # show job
  # ====URL
  #   /talents_jobs/ID
  # ===Parameters
  # invitation_token
  # rtr_id
  def show
    @talents_job.job&.viewed
    @talents_job.confirm_email
    find_invitation
  end

  private

  def find_invitation
    rtr = @talents_job.all_rtr.find_by_id(params[:rtr_id]) if params[:rtr_id]
    if @talents_job.pending_rtr.nil?
      render json: { error: 'No pending RTR found.' },
             status: :unauthorized
    elsif rtr && rtr.rejected_at
      message = if rtr.rejected_by_system
                  'Invitation token has expired.'
                else
                  'You have already rejected this job offer.'
                end
      render json: { error: message }, status: :unauthorized
    elsif @talents_job.rejected
      render json: { error: 'Invitation token has expired.' },
             status: :unauthorized
    end
  end

  def find_talents_job
    talents_job = if params[:invitation_token]
                    TalentsJob.where(invitation_token: params[:invitation_token]).first
                  else
                    current_talent.talents_jobs.where(id: params[:id]).first if current_talent
                  end

    @talents_job = talents_job || send_403!
  end
end
