json.data do
  if current_user.internal_user?
    json.powers do
      json.update current_user.can?(:update, @talents_job)
    end
  end

  json.call(@talents_job, :id, :stage)

  talent = @talents_job.talent
  if talent.present?
    json.talent do
      json.call(talent, :id, :avatar, :image_resized)
    end
  end

  profile = @talents_job.profile
  if profile.present?
    json.profile do
      json.call(
        profile,
        :id,
        :first_name,
        :last_name,
        :address,
        :city,
        :country,
        :state,
        :postal_code,
        :country_obj,
        :state_obj,
        :email
      )

      json.phones profile.phones do |phone|
        json.call(phone, :id, :number, :primary, :type)
      end
    end
  end

  job = @talents_job.job
  json.job do
    json.call(
      job,
      :id,
      :logo,
      :title,
      :display_job_id,
      :job_id,
      :type_of_job,
      :pay_period,
      :currency,
      :industry,
    )

    json.account_manager job.account_manager, :id, :first_name, :last_name, :avatar, :email

    json.onboarding_agent job.onboarding_agent, :id, :first_name, :last_name, :avatar, :email

    json.client do
      json.call(job.client, :id, :company_name)
    end

    if current_user.internal_user?
      json.category job.category.name
      json.industry job.industry
    end

    if @talents_job.assignment_detail.present?
      json.partial! '/shared/assignment_detail', talents_job: @talents_job, show_updated_by: true
    end

    if current_user.agency_user? && job.contract?
      json.incumbent current_user.incumbent?(job)
    end
  end
end
