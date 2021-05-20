if @resume.uploadable.is_a?(Profile)
  json.partial! 'resume_index', talents_jobs_resume: @resume
end
