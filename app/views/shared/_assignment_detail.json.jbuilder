assignment_detail = talents_job.assignment_detail

json.assignment_detail do
  json.call(
    assignment_detail,
    :id,
    :possibility_of_extension,
    :hours_per_week,
    :start_time,
    :end_time,
    :pay_period,
    :overtime,
    :duration,
    :duration_period,
    :city,
    :state,
    :state_obj,
    :country_obj,
    :country,
    :postal_code,
    :location,
    :timezone_id,
    :updated_at,
    :primary_end_reason,
    :secondary_end_reason
  )

  json.start_date assignment_detail.start_date.to_time.utc if assignment_detail.start_date.present?
  json.end_date assignment_detail.end_date.to_time.utc if assignment_detail.start_date.present?

  if talents_job.job.full_time? || current_user.internal_user? || current_user.agency_user?
    json.salary assignment_detail.salary
  end

  if show_updated_by
    json.confirmed_bill_rate talents_job.rtr.confirmed_bill_rate if talents_job.rtr.present?

    json.timezone assignment_detail.timezone

    if talents_job.job.contract? &&
        (current_user.internal_user? ||
        current_user.hiring_org_user? ||
        (current_user.agency_user? && current_user.incumbent?(talents_job.job)))
      offer_letter = talents_job.offer_letter
      rtr = talents_job.rtr
      salary = offer_letter&.incumbent_bill_rate.presence ||
               rtr&.incumbent_bill_rate.presence ||
               talents_job.job.incumbent_bill_rate['min']
      json.incumbent_bill_rate salary
    end

    if assignment_detail.updated_by.present?
      json.updated_by do
        json.call(
          assignment_detail.updated_by,
          :id,
          :first_name,
          :last_name,
          :avatar,
          :image_resized,
          :username
        )
      end
    end
  end
end
