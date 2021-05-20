json.data do
  json.array! @opportunities do |job|
    json.call(
      job,
      :id,
      :title,
      :logo,
      :image_resized,
      :city,
      :state,
      :state_obj,
      :country,
      :country_obj,
      :pay_period,
      :currency,
      :postal_code,
    )

    create_talents_jobs = current_user.can?(:create, TalentsJob) &&
                          job.not_closed &&
                          job.if_saved(current_user)

    incumbent = current_user&.agency&.invited_for(job)&.incumbent?
    json.incumbent incumbent

    unless current_user.hiring_org_user?
      json.suggested_pay_rate job.suggested_pay_rate
      json.marketplace_reward job.marketplace_reward unless incumbent
      json.expected_margin job.expected_margin

      unless create_talents_jobs.is_true? && @talent.if_available
        json.exists_in_opportunities current_user.exists_in_opportunities(job)
      end
    end

    json.company_name job.client.company_name

    json.if_saved job.if_saved(current_user)

    json.powers do
      json.create_talents_jobs create_talents_jobs
    end

    talents_job = @talent.talents_jobs_for(current_user, job.id)
    if talents_job.present?
      json.talents_job talents_job, :id, :stage
    end
  end
end

json.partial! 'pagination/pagination'
