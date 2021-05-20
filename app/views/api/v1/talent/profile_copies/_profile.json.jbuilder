json.call(profile, :id)

unless params[:dropdown]
  json.call(
    profile,
    :summary,
    :willing_to_relocate,
    :current_benefits,
    :hobbies,
    :work_authorization,
    :current_pay_range_min,
    :current_pay_range_max,
    :current_pay_period,
    :current_currency,
    :current_currency_obj,
    :expected_pay_range_min,
    :expected_pay_range_max,
    :expected_pay_period,
    :expected_currency,
    :expected_currency_obj,
    :compensation_notes,
    :compensation_benefits,
    :if_completed,
    :sin,
    :avatar,
    :image_resized,
    :headline,
    :address,
    :city,
    :state,
    :state_obj,
    :country,
    :country_obj,
    :first_name,
    :middle_name,
    :last_name,
    :salutation,
    :email,
    :postal_code,
    :timezone_id,
    :talent_id,
  )

  if profile.profilable
    json.user(
      profile.profilable,
      :first_name,
      :middle_name,
      :last_name,
      :username,
      :cs_email,
      :contact_no,
      :avatar,
      :image_resized
    )
  end

  json.partial! '/shared/associated_attributes', parent: profile
end
