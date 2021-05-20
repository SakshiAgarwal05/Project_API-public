json.data @records.each do |record|
  if record.is_a?(Job)
    if @invited_job_ids.include?(record.id)
      @tjs.where(job_id: record.id).each do |record|
        job = record.job
        json.(record, :id, :stage, :updated_at)
        
        if record.rtr
          json.rtr do
            json.call(
              record.rtr,
              :id,
              :start_date,
              :salary,
              :pay_period,
              :location,
              :state,
              :state_obj,
              :country,
              :country_obj,
              :city
            )

            timezone = record.rtr.timezone
            json.timezone { json.call(timezone, :id, :name, :abbr, :value) } if timezone
            json.email record.rtr.completed_transition&.email
          end
        end

        json.job do
          json.(
            job,
            :id,
            :title,
            :logo,
            :published_at,
            :type_of_job,
            :display_job_id,
            :job_id,
            :positions,
            :type_of_job,
            :start_date,
            :stage,
            :address,
            :state,
            :image_resized,
            :state,
            :state_obj,
            :country,
            :country_obj,
            :city,
            :start_date,
            :updated_at
          )

          json.client job.client, :logo, :id, :image_resized if job.client
          json.category job.category, :id, :name if job.category
          json.industry job.industry, :id, :name if job.industry
        end

        json.user do
          json.call(record.user, :id, :first_name, :last_name) if record.user
        end
      end
    else
      json.(
        record,
        :id,
        :title,
        :logo,
        :published_at,
        :type_of_job,
        :display_job_id,
        :job_id,
        :positions,
        :address,
        :state,
        :image_resized,
        :state_obj,
        :country,
        :country_obj
      )

      json.category record.category, :id, :name if record.category
      json.client record.client, :company_name, :id, :logo, :image_resized if record.client
      json.industry record.industry, :id, :name if record.industry
    end

  elsif record.is_a?(TalentsJob)
    job = record.job
    json.(record, :id, :stage, :updated_at)
    if record.rtr
      json.rtr do
        json.call(
          record.rtr,
          :id,
          :start_date,
          :salary,
          :pay_period,
          :location,
          :state,
          :state_obj,
          :country,
          :country_obj,
          :city
        )

        timezone = record.rtr.timezone
        json.timezone { json.call(timezone, :id, :name, :abbr, :value) } if timezone
        json.email record.rtr.completed_transition&.email
      end
    end

    json.job  do
      json.(
        job,
        :id,
        :title,
        :logo,
        :published_at,
        :type_of_job,
        :display_job_id,
        :job_id,
        :positions,
        :type_of_job,
        :start_date,
        :stage,
        :address,
        :state,
        :image_resized,
        :state,
        :state_obj,
        :country,
        :country_obj,
        :city,
        :start_date,
        :updated_at
      )
      json.client job.client, :logo, :id, :image_resized if job.client
      json.category job.category, :id, :name if job.category
      json.industry job.industry, :id, :name if job.industry
    end
    json.user do
      json.call(record.user, :id, :first_name, :last_name) if record.user
    end
  else
    json.data []
  end
end

json.partial! 'pagination/pagination', obj: @records, total_count: @total_count
