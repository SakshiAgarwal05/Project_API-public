json.call(
  @event,
  :id,
  :title,
  :event_type,
  :start_date_time,
  :end_date_time,
  :related_to_type,
  :related_to_id,
  :finished,
  :media,
  :request,
  :created_at,
  :updated_at,
  :reminder_in_minutes,
  :location,
  :note,
  :job_id,
  :meeting_url,
  :dial_in_number,
  :access_code,
  :declined,
  :decline_reason,
  :user_id,
  :latitude,
  :longitude,
  :confirmed,
  :deleted_at
)

json.status @event.status(nil, @attendee)

if @event.job
  json.related_to_obj do
    json.call(
      @event.job,
      :id,
      :created_at,
      :updated_at,
      :city,
      :state,
      :state_obj,
      :country,
      :country_obj,
      :postal_code,
      :title,
      :display_job_id,
      :stage,
    )
    json.logo @event.client.logo
  end
  json.related_to_text @event.job.title

  hiring_organization = @event.job.hiring_organization
  if hiring_organization
    json.hiring_organization(
      hiring_organization,
      :id,
      :company_relationship_name,
      :company_relationship
    )
  end
end

json.attendees do
  json.array! @event.event_attendees.common_order.each do |attendee|
    json.call(
      attendee,
      :id,
      :email,
      :user_id,
      :talent_id,
      :optional,
      :is_host,
      :is_organizer,
      :status,
      :first_name,
      :middle_name,
      :last_name,
      :name,
      :avatar,
      :primary_role,
      :invitation_token,
      :confirmed_slots,
    )
    json.declined_slots @event.time_slot_ids if attendee.status.eql?('No') && @event.time_slots
  end
end

if @event.time_slots.present?
  json.time_slots do
    json.array! @event.time_slots.each do |time_slot|
      json.call(time_slot, :id, :start_date_time, :end_date_time, :created_at, :updated_at)
    end
  end
  json.attendees_available @event.attendees_available
end

json.client do
  json.id @event.client_id
  json.company_name @event.client&.company_name
end

json.current_attendee do
  json.call(
    @attendee,
    :id,
    :email,
    :user_id,
    :talent_id,
    :optional,
    :is_host,
    :is_organizer,
    :status,
    :first_name,
    :last_name,
    :middle_name,
    :name,
    :avatar,
    :primary_role,
    :confirmed_slots
  )
  json.declined_slots @event.time_slot_ids if @attendee.status.eql?('No') && @event.time_slots
end
