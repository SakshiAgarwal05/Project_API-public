# Controller to view Jobs[../Job.html].
class JobsController < ApplicationController

  skip_load_and_authorize_resource only: [:update]
  before_action :find_public_job, only: [:apply_to_job, :earning]
  before_action :find_job, only: [:show, :reject, :update, :similar]
  before_action :find_invitation, only: [:reject, :update]

  # List all public jobs.
  # ====URL
  #   /jobs [GET]
  # ====Parameters
  #   order_field (sort by fields name)
  #   order (sort order asc/desc)
  #   page (page number)
  #   per_page (records per page)
  #   cilent_id
  def index
    jobs = Job.published_to_cs_including_onhold
    jobs = jobs.not_saved_by_talent(current_talent) if current_talent
    jobs = jobs.where(client_id: params[:client_id]) if params[:client_id]
    @jobs = jobs.includes(:client, :category)
      .order((params[:order_field] || :created_at) => get_order('desc'))
      .page(page_count).per(per_page)
  end

  # List similar jobs.
  # ====URL
  #   /jobs/job_id/similar [GET]
  # ====Parameters
  #   order_field (sort by fields name)
  #   order (sort order asc/desc)
  #   page (page number)
  #   per_page (records per page)
  def similar
    @jobs = @job.similar_jobs.page(page_count).per(per_page)
    render template: 'jobs/index'
  end

  # search on jobs
  # ====URL
  #   /jobs/search
  # ====PARAMETERS
  #  query (job title | client name | skills)
  #  location (city, state, country)
  #  distance (10, 50, 100, 200, 250+)
  #  duration.
  #  client_name
  #  industry_name
  #  category_name
  #  location_type
  #  years_of_experience
  #  currency
  #  stage
  # def search
  #   begin
  #     params[:page] = page_count
  #     params[:per_page] = per_page
  #     if current_talent
  #       job_ids = current_talent.jobs.pluck(:id).uniq
  #       params.merge!(ids_nin: job_ids)
  #     end
  #     @jobs, @total_count = Job.search_jobs_for_talent(search_params)
  #     render template: 'jobs/index'
  #   rescue RuntimeError => e
  #     render json: {error: [e.message]}, status: :unprocessable_entity
  #   end
  # end

  # search on jobs
  # ====URL
  #   /jobs/search
  # ====PARAMETERS
  #  query (job title | client name | skills)
  #  city, state, country
  def suggestions
    begin
      render(
        json: {
          data: Elasticsearch::Model.search(
            {
              query: {
                match: {
                  'name.autocomplete': params[:query]
                }
              },
              _source: [
                'name'
              ]
            },
            [Job, Client, Category, Industry, Skill]
          ).map { |result| result._source.name }
        }
      )
    rescue RuntimeError => e
      render json: {error: [e.message]}, status: :unprocessable_entity
    end
  end

  # show job
  # ====URL
  #   /jobs/JOB_ID?invitation_token=TOKEN
  # ====PARAMETERS
  #   refresh (true/false/nil)
  # TODO : CRWDPLT-1457 Suppose refresh page again and again.
  def show
    @job.viewed
    if params[:invitation_token]
      find_invitation
      @talents_job.view_invitation(@talents_job.pending_rtr) if @talents_job
    elsif params[:talents_job_id].present?
      @talents_job = TalentsJob.find(params[:talents_job_id])
    elsif !@job.publish_to_cs
      send_403!
    end
  end

  # reject a job without logging in.
  # ====URL
  #   /jobs/ID?invitation_token=TOKEN [PUT]
  def update
    render(
      json: {
        talent_id: @talents_job.talent.id,
        confirmed: @talents_job.talent.confirmed?,
        confirmed_at: @talents_job.talent.confirmation_sent_at,
        email: @talents_job.talent.email,
      },
      status: :ok
    )
  end

  # reject a job without logging in.
  # ====URL
  #   /jobs/ID/reject?invitation_token=TOKEN [PUT]
  # ====PARAMETERS
  #   contact_by_phone
  #   contact_by_email
  #   withdrawn_notes
  #   reason_to_withdrawn
  def reject
    rtr = @talents_job.pending_rtr
    unless rtr
      rtr_not_available #MISS(TODO: TEST CASES NOT WRITTEN)
    else
      rtr_params = {rejected_at: Time.now,
        reject_reason: [params[:reason_to_withdrawn], params[:withdrawn_notes]].compact.join('-')}
      rtr.update_attributes(rtr_params) ? render(json: @talents_job, status: :ok) : render_errors(rtr)
      unless @talents_job.signed?
        save_candidate_dnd(@talents_job)
      end
    end
  end

  # candidate sign up and apply for a job for which he is not yet invited.
  # ====URL
  #   /talent/jobs/ID/apply_to_job [POST]
  # ====PARAMETERS
  #   talent[email]
  #   talent[password]
  #   talent[password_confirmation]
  #   talent[first_name]
  #   talent[last_name]
  #   talent[phones][][type]
  #   talent[phones][][number]
  #   talent[resume_path]
  #   talent[middle_name]
  #   talent[city]
  #   talent[state]
  #   talent[country]
  #   talent[country_obj]
  #   talent[state_obj]
  #   talent[postal_code]
  #   talents_job[questionnaire_answers][][question_id]
  #   alents_job[questionnaire_answers][][answer]
  #   talents_job[message]
  def apply_to_job
    share_link = ShareLink.find(params[:shared_id])
    if share_link.present?
      params[:talent][:password_set_by_user] = true if params[:talent]
      tp = talent_params
      if params[:got_resume].is_true? && tp[:resume_path].nil?
        render json: { error: ['Please upload resume'] },
               status: :unprocessable_entity
      else
        talent = Talent.new(tp)
        duplicates = talent.find_duplicates
        if duplicates.empty?
          if talent.valid?
            talent.save
            build_resume_and_job_apply(talent, share_link, params[:referrer], false)
          else
            render_errors(talent)
          end
        else
          render(
            json: {
              error: "We've already got you registered, try to login or double
                check the details provided",
            },
            status: 422
          )
        end
      end
    else
      send_403!
    end
  end

  # URL ====================
  #  /jobs/handle_old_urls [POST]
  # PARAMETERS =============
  #  invitation_token
  def handle_old_urls
    talents_job = TalentsJob.find_by(invitation_token: params[:invitation_token]) if params[:invitation_token]
    talents_job.nil? ?
      send_403! :
      render(json: {id: talents_job.id})
  end

  private

  def save_candidate_dnd(talents_job)
    talent = talents_job.talent
    unless talent.confirmed?
      talent.contact_by_phone = params[:contact_by_phone]
      talent.contact_by_email = params[:contact_by_email]
      talent.save(validate: false)
    end
  end

  def find_invitation
    @talents_job = @job.find_invitation(params[:invitation_token])
    if @talents_job.blank?
      render json: { error: 'Invitation token has expired.' },
             status: :unauthorized
    elsif @talents_job.pending_rtr.nil?
      render json: { error: 'No pending RTR found.' },
             status: :unauthorized
    elsif @talents_job.withdrawn
      render json: { error: 'You have already rejected this job offer.' },
             status: :unauthorized
    elsif @talents_job.signed?
      render json: { error: 'You have already signed this job offer.' },
             status: :unauthorized
    end
  end

  def find_job
    @job = Job.published.find(params[:id]) || send_403!
  end

  def find_public_job
    @job = Job.published_to_cs_including_onhold.find(params[:id]) || send_403!
  end

  def search_params
    params.permit(
      :query,
      :location,
      :duration,
      :type_of_job,
      :order_field,
      :order,
      :page,
      :per_page,
      :pay_period,
      :salary_min,
      :salary_max,
      :distance,
      years_of_experience: [],
      location_type: [],
      client_name: [],
      industry_name: [],
      category_name: [],
      currency: [],
      stage: [],
      ids_nin: []
    )
  end

  def talent_params
    if params[:talent][:phones]
      params[:talent][:phones].each do |phone|
        phone[:confirmed] = true
      end
    end

    params.require(:talent).permit(
      :first_name,
      :last_name,
      :email,
      :send_emails,
      :password_set_by_user,
      :city,
      :state,
      :country,
      :postal_code,
      :password,
      :password_confirmation,
      :resume_path,
      country_obj: [:id, :name, :abbr ],
      state_obj: [:id, :name, :abbr ],
      phones: [:type, :number, :id, :_destroy, :primary],
      emails: [:type, :email, :id, :_destroy, :primary, :confirmed]
    )
  end
end
