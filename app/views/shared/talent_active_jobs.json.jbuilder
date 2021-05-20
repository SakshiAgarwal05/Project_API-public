json.data do
  json.array! @talents_jobs do |talents_job|
    json.call(talents_job, :id, :stage, :rejected, :withdrawn)

    job = talents_job.job
    if job
      json.job do
        json.call(
          job,
          :id,
          :stage,
          :display_job_id,
          :job_id,
          :title,
          :start_date,
          :state_obj,
          :state,
          :country,
          :country_obj,
          :published_at,
          :city, :address,
          :type_of_job,
          :currency,
          :pay_period,
          :logo,
          :image_resized,
          :positions,
          :duration,
          :duration_period,
          :suggested_pay_rate,
          :marketplace_reward,
          :expected_margin
        )
        json.if_saved job.if_saved(current_user)
      end
    end
  end
end

json.partial! 'pagination/pagination'
