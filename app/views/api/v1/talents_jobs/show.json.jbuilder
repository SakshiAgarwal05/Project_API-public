job = @talents_job.job
json.call(@talents_job, :id, :stage)
json.job do
  json.call(
    job,
    :id,
    :title,
    :city,
    :country,
    :country_obj,
    :state,
    :state_obj,
    :type_of_job,
    :summary,
    :responsibilities,
    :preferred_qualification,
    :published_at,
    :job_id,
    :display_job_id,
    :enable_questionnaire
  )

  json.benefits job.benefits || []
  client = job.client
  if client
    json.client do
      json.call(client, :id, :company_name, :about, :logo)
      json.industry client.industry, :id, :name if client.industry
      json.jobs_count client.jobs.count
      json.links client.links do |link|
        json.call(link, :id, :type, :link)
      end
    end
  end
  json.category job.category, :id, :name if job.category
  json.skills job.skills, :name, :id if job.skills
end

json.talents_jobs do
  json.call(@talents_job, :id, :stage)

  if @talents_job.rtr
    json.rtr do
      json.call(
        @talents_job.rtr,
        :location,
        :duration,
        :duration_period,
        :salary,
        :pay_period,
        :hours_per_week,
        :start_date,
        :start_time,
        :end_time,
        :signed_at,
        :rejected_at,
        :state,
        :state_obj,
        :country,
        :country_obj,
        :postal_code,
        :benefits_added,
        :benefits,
        :offline,
        :offline_rtr_doc,
        :questionnaire_status
      )

      timezone = @talents_job.rtr.timezone
      json.timezone { json.call(timezone, :id, :name, :abbr, :value) } if timezone
      json.dnd_checkbox @talents_job.talent.dnd_checkbox?
    end
  end

  json.revised_rtr @talents_job.signed?

  if @talents_job
    talent = @talents_job.profile
    if talent
      json.talent do
        json.call(
          @talents_job.talent,
          :id,
          :avatar,
          :image_resized,
          :verified,
          :password_set_by_user,
          :temporary_auth_token,
        )


        json.call(
          talent,
          :first_name,
          :last_name,
          :middle_name,
          :city,
          :state,
          :state_obj,
          :country,
          :country_obj,
          :postal_code
        )
        json.profile_id @talents_job.profile_id
        json.email @talents_job.email

        json.emails talent.emails do |email|
          json.call(
            email,
            :id,
            :email,
            :type,
            :primary,
          )
          json.confirmed email.confirmed?
        end
        json.phones talent.phones, :type, :number, :primary, :id, :confirmed

      end
    end
  end

  user = @talents_job.user
  if user
    json.user do
      json.call(
        user,
        :id,
        :first_name,
        :last_name,
        :avatar,
        :image_resized,
        :username,
        :current_sign_in_ip,
        :last_sign_in_ip,
        :cs_email,
        :contact_no,
        :primary_role,
        :email_signature
      )

      json.phones(user.phones, :type, :number, :primary, :confirmed)

      agency = user.agency
      json.agency agency, :id, :company_name if agency
    end
  end

  if @talents_job.questionnaire_presence?
    json.partial! '/shared/questionnaire', talents_job: @talents_job
  else
    json.questionnaire []
  end
end
