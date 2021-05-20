talent = @talents_job.talent
json.call(
  @rtr,
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

timezone = @rtr.timezone
json.timezone { json.call(timezone, :id, :name, :abbr, :value) } if timezone
json.revised_rtr @talents_job.signed?
json.dnd_checkbox @talents_job.talent.dnd_checkbox?
json.tag @rtr.show_status
json.email @rtr.completed_transition&.email
json.timeline_notifications @rtr.talentapp_notifications do |noti|
  notification_from = noti.from
  if notification_from
    if notification_from.is_a?(User)
      json.from do
        json.(notification_from, :id, :first_name, :last_name, :username, :email, :cs_email)
        json.internal_user notification_from.internal_user?
      end
    elsif notification_from.is_a?(Talent)
      json.from do
        json.(notification_from, :id, :first_name, :last_name, :email)
      end
    end
  end
end
if talent
  json.talent do
    json.call(talent, :id, :first_name, :last_name, :email, :avatar, :image_resized)
    json.verified talent.verified
  end
end
