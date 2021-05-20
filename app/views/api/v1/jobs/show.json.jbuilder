json.job do
  json.call(
    @job,
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
    :minimum_qualification,
    :published_at,
    :publishing_privacy_setting,
    :enable_questionnaire
  )

  client = @job.client
  if client
    if @job.publishing_privacy_setting.is_true?
      json.client do
        json.logo 'https://crowdstaffing-production-public.s3-us-west-2.amazonaws.com/cs-emblem.png'
        json.logo_banner 'https://crowdstaffing-production-public.s3-us-west-2.amazonaws.com/cs-emblem.png'
        json.company_name 'Crowdstaffing'
      end
    else
      json.client do
        json.call(client, :id, :company_name, :about, :logo)
        json.industry client.industry, :id, :name if client.industry
        json.jobs_count client.jobs.count
        json.logo client.logo
        json.logo_banner client.logo_banner
        json.links client.links do |link|
          json.call(link, :id, :type, :link)
        end
      end
    end
  end

  json.category @job.category, :id, :name if @job.category
  json.skills @job.skills, :name, :id if @job.skills
  json.industry @job.industry, :name, :id if @job.industry
  json.benefits @job.benefits || []
end

if @talents_job
  transition = @talents_job.latest_transition_obj
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
          :offline_rtr_doc
        )

        timezone = @talents_job.rtr.timezone
        json.timezone { json.call(timezone, :id, :name, :abbr, :value) } if timezone
      end
    end

    json.revised_rtr @talents_job.signed?

    if @talents_job
      talent = @talents_job.talent
      if talent
        json.talent do
          json.call(
            talent,
            :avatar,
            :image_resized,
            :first_name,
            :last_name,
            :middle_name,
            :email,
            :verified,
            :password_set_by_user,
            :temporary_auth_token,
            :city,
            :state,
            :state_obj,
            :country,
            :country_obj,
            :postal_code
          )

          json.emails talent.emails do |email|
            json.call(email, :id, :email, :type, :primary,)
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
          :contact_no
        )

        json.phones(user.phones, :type, :number, :primary)

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
end
