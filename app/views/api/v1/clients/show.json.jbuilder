json.call(
  @client,
  :id,
  :company_name,
  :about,
  :logo,
  :city,
  :state,
  :state_obj,
  :country,
  :country_obj
)

json.industry @client.industry, :id, :name if @client.industry
json.jobs_count @client.cs_active_jobs_count
json.links @client.links do |link|
  json.(link, :id, :type, :link)
end
