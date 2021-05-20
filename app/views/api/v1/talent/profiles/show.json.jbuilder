profile = @talent.talent_profile_copy || @talent
talent = @talent
json.call(
  talent,
  :id,
  :avatar,
  :image_resized,
  :contact_by_phone,
  :contact_by_email, 
  :resume,
  :parse_resume,
  :resume_path,
  :resume_path_pdf,
  :profile_status,
  :password_updated_at,
  :start_date,
  )

json.call(
  profile,
  :first_name,
  :last_name,
  :middle_name,
  :salutation,
  :email,
  :sin,
  :address,
  :city,
  :state,
  :country,
  :state_obj,
  :country_obj,
  :postal_code,
  :summary,
  :willing_to_relocate,
  :hobbies,
  :current_pay_range_min,
  :current_pay_range_max,
  :current_pay_period,
  :current_currency,
  :current_currency_obj,
  :expected_pay_range_min,
  :expected_pay_range_max,
  :expected_pay_period,
  :current_benefits,
  :compensation_benefits,
  :expected_currency,
  :expected_currency_obj,
  :compensation_notes,
  :work_authorization,
  :blank_fields,
  :complete,
  :years_of_experience,
  :timezone_id,
  :if_completed,
)


json.links profile.links do |link|
  json.(link, :id, :type, :link,)
end

json.educations profile.educations do |education|
  json.(
    education,
    :id,
    :school,
    :degree,
    :city,
    :country,
    :studying,
    :country_obj,
    :start_date,
    :end_date
  )
end

json.experiences profile.experiences do |experience|
  json.(
    experience,
    :id,
    :title,
    :company,
    :city,
    :country,
    :city,
    :country,
    :working,
    :description,
    :country_obj
  )

  json.start_date daxtra_date(experience.start_date)
  json.end_date daxtra_date(experience.end_date)
end

json.languages profile.languages do |language|
  json.(language, :id, :name, :proficiency)
end

json.skills profile.skills do |skill|
  json.(skill, :id, :name)
end

json.industries profile.industries do |industry|
  json.(industry, :id, :name, :agency_ids)
end

json.media profile.media do |medium|
  json.(medium, :id, :file, :title, :description)
end

json.phones profile.phones do |phone|
  json.(phone, :id, :number, :primary, :type)
end

json.emails profile.emails do |email|
  json.call(email, :id, :email, :type, :primary,)
  json.confirmed email.confirmed?
end

json.certifications profile.certifications do |certification|
  json.(certification, :id, :start_date, :vendor_id, :certificate_id)

  json.vendor_name(certification.vendor.name) if certification.vendor

  json.certificate_name(certification.certificate.name) if certification.certificate
end

json.timezone(profile.timezone, :id, :abbr, :name, :value) if profile .timezone

talent_preference = talent.talent_preference
if talent_preference
  json.talent_preference do
    json.call(
      talent_preference,
      :id,
      :experience_range,
      :pay_period,
      :currency,
      :currency_obj,
      :working_hours,
      :pay_period,
      :benefits,
      :work_type,
      :relocate,
      :relocation_assistance,
      :remote,
      :base_amount,
      :blank_fields
    )

    json.partial! 'industry_and_position', parent: talent_preference

    json.locations(talent_preference.locations, :id, :address, :city, :state, :country)
  end
else
  json.talent_preference do
    json.benefits []
    json.working_hours []
  end
end

json.interview_slots talent.interview_slots do |slot|
  json.(slot, :id, :slot, :note,)
end
json.matching_job_title({})
json.resume_status talent.profile_status
json.job_preferences_completed talent.preferences_completed
