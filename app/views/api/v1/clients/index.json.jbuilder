
json.data do
  json.array! @clients do |client|
    json.(
      client,
      :id,
      :company_name,
      :logo,
      :image_resized,
      :city,
      :state_obj,
      :country_obj,
      :city,
      :cs_active_jobs_count,
      :about
    )

    json.industry client.industry, :id, :name if client.industry
  end
end

json.partial! 'pagination/pagination', obj: @clients, total_count: @total_count
