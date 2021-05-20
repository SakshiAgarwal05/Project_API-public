json.call(talents_job, :id, :stage)

profile = talents_job.profile
if profile
  json.profile do
    json.call(
      profile,
      :id,
      :first_name,
      :last_name,
      :email,
      :address,
      :postal_code,
      :city,
      :state,
      :country_obj,
      :state_obj,
      :country,
    )
  end
end

talent = talents_job.talent
if talent
  json.talent do
    json.call(talent, :id, :avatar, :image_resized)
  end
end

json.job do
  job = talents_job.job
  json.call(
    job,
    :id,
    :logo,
    :title,
    :display_job_id,
    :job_id,
    :type_of_job,
    :pay_period,
    :currency
  )

  json.suggested_pay_rate job.suggested_pay_rate if current_user.internal_user?

  json.overtime talents_job.overtime?

  json.client job.client, :id, :company_name
end

if talents_job.assignment_detail.present?
  json.partial! '/shared/assignment_detail', talents_job: talents_job, show_updated_by: false
end
