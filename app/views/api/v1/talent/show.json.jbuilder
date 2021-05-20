job = @talents_job.job
json.call(@talents_job, :id, :stage)

if @talents_job.rtr.present?
  json.rtr(@talents_job.rtr, :id, :signed_at, :rejected_at)
end

if @talents_job.questionnaire_presence?
  json.partial! '/shared/questionnaire', talents_job: @talents_job
else
  json.questionnaire []
end

json.powers do
  json.can_contact_from_talentapp @talents_job.onboarded?
end
# Contact Tab - only visible if and when the candidate is being on-boarded
json.user do
  if @talents_job.user
    json.call(
      @talents_job.user,
      :id,
      :first_name,
      :last_name,
      :email,
      :cs_email,
      :avatar,
      :image_resized,
      :contact_no,
      :username,
      :primary_role,
      :email_signature
    )

    json.agency @talents_job.user.agency if @talents_job.user.agency_user?
  end
end

incumbent = @talents_job.user&.agency&.invited_for(job)&.incumbent?
json.incumbent incumbent

json.account_manager do
  if job.account_manager
    json.call(
      job.account_manager,
      :id,
      :first_name,
      :last_name,
      :cs_email,
      :avatar,
      :image_resized,
      :contact_no,
      :username,
      :email
    )
  end
end

json.onboarding_agent do
  if job.onboarding_agent
    json.call(
      job.onboarding_agent,
      :id,
      :first_name,
      :last_name,
      :cs_email,
      :avatar,
      :image_resized,
      :contact_no,
      :username,
      :email
    )
  end
end

cts = @talents_job.completed_transitions
json.completed_transitions cts do |ct|
  json.call(
    ct,
    :stage,
    :tag,
    :created_at,
    :updated_at,
    :note,
    :subject,
    :body,
    :tag_note,
    :current
  )

  if ct.updated_by
    json.updated_by(
      ct.updated_by,
      :id, :first_name, :last_name, :email
    )
  end
end

# json.current_offer_letter @talents_job.offer_letter, :id if @talents_job.offer_letter.show_status.eql?('sent')
offer_letter = @talents_job.offer_letter
  if offer_letter && offer_letter.active?
    json.current_offer_letter do
      json.call(
        offer_letter,
        :id,
        :location,
        :duration,
        :duration_period,
        :salary,
        :pay_period,
        :reject_reason,
        :reject_notes,
        :hours_per_week,
        :start_date,
        :start_time,
        :end_time,
        :benefits,
        :send_as_representer,
        :created_at,
        :updated_at,
        :possibility_of_extension,
        :subject,
        :welcome_message,
        :additional_notes,
        :exit_message,
        :city,
        :country,
        :country_obj,
        :state,
        :state_obj,
        :postal_code,
        :incumbent_bill_rate,
        :incumbent_bill_period,
        :notify_collaborators,
        :recipient
      )

      json.end_date offer_letter.end_date if offer_letter.end_date
      timezone = offer_letter.timezone
      json.timezone { json.call(timezone, :id, :name, :abbr, :value) } if timezone

      if offer_letter.updated_by
        json.updated_by do
          json.call(
            offer_letter.updated_by,
            :id,
            :first_name,
            :last_name,
            :avatar,
            :image_resized,
            :username
          )
        end
      end

      json.status offer_letter.show_status
      json.signed_at @talents_job.offer_accepted.created_at if @talents_job.offer_accepted
      json.rejected_at @talents_job.offer_rejected.updated_at if @talents_job.offer_rejected
      json.tag offer_letter.completed_transition.tag
      json.tag_note offer_letter.completed_transition.tag_note
    end
  end

latest_transition = @talents_job.latest_transition_obj
if latest_transition
  json.latest_transition do
    json.call(latest_transition, :id, :stage, :note, :subject, :body, :tag, :tag_note)
  end
end

if @talents_job.latest_transition_obj.pipeline_step
  json.current_stage(
    @talents_job.latest_transition_obj.pipeline_step,
    :id,
    :stage_type,
    :stage_label,
    :stage_description,
    :stage_order,
    :fixed,
    :visible,
    :eventable
  )
end

# candidate profile - Check all required fields
if @talents_job.profile
  json.profile do
    json.call(@talents_job.profile, :id, :first_name, :last_name, :avatar, :image_resized, :email)
    json.verified @talents_job.talent.verified
  end
end

json.job do
  json.call(
    job,
    :id,
    :title,
    :country,
    :country_obj,
    :state,
    :state_obj,
    :start_date,
    :type_of_job,
    :years_of_experience,
    :suggested_pay_rate,
    :summary,
    :logo,
    :image_resized,
    :published_at,
    :no_of_views,
    :pay_period,
    :available_positions,
    :display_job_id,
    :job_id,
    :city,
    :duration,
    :duration_period,
    :responsibilities,
    :positions,
    :minimum_qualification,
    :preferred_qualification,
    :additional_detail,
    :currency,
    :stage,
    :enable_questionnaire
  )
  json.benefits job.benefits || []
  json.category job.category, :id, :name if job.category
  json.client job.client, :company_name, :id if job.client
  json.industry job.industry, :id, :name if job.industry

  json.skills job.skills, :name, :id if job.skills

  json.timezone job.timezone, :name, :id, :abbr if job.timezone

  json.resume_status @talents_job.talent.profile_status
  json.job_preferences_completed @talents_job.talent.preferences_completed

  if current_talent
    talents_job = job.current_user_talents_job(current_talent)
    if talents_job
      json.current_user_talents_job do
        json.call(talents_job, :rejected, :withdrawn, :interested)
      end
    end
  end
end
