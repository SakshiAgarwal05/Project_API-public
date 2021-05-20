json.call(
  @offer_letter,
  :id,
  :location,
  :duration,
  :duration_period,
  :salary,
  :pay_period,
  :reject_reason,
  :reject_notes,
  :hours_per_week,
  :start_date,
  :start_time,
  :end_time,
  :benefits,
  :send_as_representer,
  :created_at,
  :updated_at,
  :updated_by_id,
  :start_time,
  :end_time,
  :possibility_of_extension,
  :end_date,
  :incumbent_bill_period,
  :welcome_message,
  :exit_message,
  :additional_notes,
  :subject,
  :notify_collaborators,
  :incumbent_bill_rate,
  :cancel,
  :reason_note,
  :address,
  :city,
  :city_obj,
  :state,
  :state_obj,
  :country,
  :country_obj,
  :postal_code,
  :recipient,
  :end_date,
)

timezone = @offer_letter.timezone
json.timezone { json.call(timezone, :id, :name, :abbr, :value) } if timezone
json.tag @talents_job.latest_transition_obj.tag
json.tag_note @talents_job.latest_transition_obj.tag_note


if @offer_letter.updated_by
  json.updated_by do
    json.(
      @offer_letter.updated_by,
      :id,
      :first_name,
      :last_name,
      :avatar,
      :image_resized,
      :username,
      :current_sign_in_ip,
      :last_sign_in_ip,
      :email,
      :primary_role
    )
    json.verified @offer_letter.updated_by.confirmed_at? if @offer_letter.updated_by
    json.phone @offer_letter.updated_by.contact_no
  end
end

talent = @talents_job.talent
if talent
  json.talent do
    json.call(talent, :id, :first_name, :last_name, :email, :avatar, :image_resized)
    json.verified talent.verified
  end
end

json.signed_at @talents_job.offer_accepted.created_at if @talents_job.offer_accepted
json.rejected_at @talents_job.offer_rejected.updated_at if @talents_job.offer_rejected
json.timeline_notifications @offer_letter.talentapp_notifications do |notification|
  json.partial! 'talent/offer_letters/notification', notification: notification
end