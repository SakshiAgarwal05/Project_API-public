json.experiences parent.experiences do |experience|
  json.(experience, :id, :title, :company, :city, :working, :country, :country_obj, :description)

  json.start_date daxtra_date(experience.start_date)
  json.end_date daxtra_date(experience.end_date)
end

json.educations parent.educations do |education|
  json.(
    education,
    :id,
    :school,
    :degree,
    :city,
    :studying,
    :country,
    :country_obj,
    :start_date,
    :end_date
  )
end

json.languages parent.languages do |language|
  json.(language, :id, :name, :proficiency)
end

json.skills parent.skills do |skill|
  json.(skill, :id, :name)
end

json.media parent.media do |media|
  json.(media, :id, :file, :title, :description)
end

json.links parent.links do |link|
  json.(link, :id, :type, :link)
end

json.emails parent.emails do |email|
  json.call(email, :id, :email, :type, :primary)
  json.confirmed email.confirmed?
end

json.phones parent.phones do |phone|
  json.call(phone, :id, :number, :type, :primary, :confirmed)
end

json.timezone(parent.timezone, :abbr, :id, :name, :value) if parent.timezone
json.partial! '/shared/industry_and_position', parent: parent
