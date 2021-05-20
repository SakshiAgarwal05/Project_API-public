talent_preference = @talent.talent_preference
if talent_preference
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
    :blank_fields,
    :pay_range_max
  )

  json.partial! 'shared/industry_and_position', parent: talent_preference

  json.locations(
    talent_preference.locations,
    :id,
    :address,
    :city,
    :state,
    :country
  )
end
