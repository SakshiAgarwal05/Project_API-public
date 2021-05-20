job_events = job_events_count(jobs, events)
json.data jobs do |job|
  json.id job.id
  json.title job.title
  json.display_job_id job.display_job_id
  json.job_id job.job_id
  if params[:query]
    json.event_count get_search_events_count(@search_params, {job_ids: [job.id], only_count: true})
  else
  	json.event_count job_events[job.id]
  end
  json.closed job.is_closed?
end
