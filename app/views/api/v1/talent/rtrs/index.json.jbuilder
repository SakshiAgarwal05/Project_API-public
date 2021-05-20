json.data do
  json.array! @rtrs do |rtr|
    json.(
      rtr,
      :id,
      :location,
      :duration,
      :duration_period,
      :salary,
      :pay_period,
      :hours_per_week,
      :start_date,
      :start_time,
      :end_time,
      :signed_at,
      :rejected_at,
      :reject_reason,
      :subject,
      :body,
      :updated_at,
      :created_at,
      :state,
      :state_obj,
      :country,
      :country_obj,
      :postal_code,
      :benefits_added,
      :benefits,
      :offline,
      :offline_rtr_doc
    )

    status = rtr.show_status_of_rtr
    json.status status
    json.status_date rtr.status_date(status)
    json.tag rtr.show_status
    timezone = rtr.timezone
    json.timezone { json.call(timezone, :id, :name, :abbr, :value) } if timezone
    json.email rtr.completed_transition&.email
    json.timeline_notifications rtr.talentapp_notifications do |notification|
      json.(notification, :id, :created_at, :updated_at, :message, :user_agent)

      from = notification.from
      if from && from.is_a?(User)
        json.from from, :id, :cs_email, :username, :first_name, :last_name
      elsif from && from.is_a?(Talent)
        json.from from, :id, :email, :name, :first_name, :last_name
      end
    end
  end
end