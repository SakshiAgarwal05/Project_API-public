json.data do
  json.array! @jobs do |job|
    json.(
      job,
      :id,
      :type_of_job,
      :city,
      :state,
      :state_obj,
      :country,
      :country_obj,
      :title,
      :published_at
    )
    if job.publishing_privacy_setting.is_true?
      json.client do
        json.logo 'https://crowdstaffing-production-public.s3-us-west-2.amazonaws.com/cs-emblem.png'
        json.company_name 'Crowdstaffing'
      end
    else
      json.client job.client, :id, :logo, :company_name
    end
    json.category job.category, :id, :name if job.category
    json.industry job.industry, :id, :name if job.industry
  end
end
json.partial! 'pagination/pagination', obj: @jobs, total_count: @total_count
