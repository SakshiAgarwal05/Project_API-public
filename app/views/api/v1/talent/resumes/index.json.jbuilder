json.data do
  json.array! @talents_jobs_resumes do |talents_jobs_resume|
    json.partial! 'resume_index', talents_jobs_resume: talents_jobs_resume
  end
end