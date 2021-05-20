json.call(
  offer,
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
)

json.end_date offer.end_date if offer.end_date
timezone = offer.timezone
json.timezone { json.call(timezone, :id, :name, :abbr, :value) } if timezone

if offer.updated_by
  json.updated_by do
    json.call(
      offer.updated_by,
      :id,
      :first_name,
      :last_name,
      :avatar,
      :image_resized,
      :username
    )
  end
end

json.status offer.show_status
json.tag offer.completed_transition.tag
json.tag_note offer.completed_transition.tag_note

if offer.model_name == 'OfferLetter'
  json.recipient offer.recipient
  json.signed_at tj.offer_accepted.created_at if tj.offer_accepted
  json.rejected_at tj.offer_rejected.updated_at if tj.offer_rejected
end
