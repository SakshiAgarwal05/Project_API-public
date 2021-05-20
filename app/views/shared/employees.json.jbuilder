json.data do
  json.array! @talents_jobs.includes(:assignment_detail, :profile, :talent, job: :client),
              partial: 'shared/employee',
              as: :talents_job
end

json.partial! 'pagination/pagination', obj: @talents_jobs
