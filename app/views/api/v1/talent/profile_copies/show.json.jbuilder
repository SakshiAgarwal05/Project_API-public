json.partial! 'profile', profile: @profile
json.timezone(@profile.timezone, :id, :abbr, :name, :value) if @profile.timezone
json.certifications @profile.certifications do |certification|
  json.(certification, :id, :start_date, :vendor_id, :certificate_id)
  json.vendor_name(certification.vendor.name) if certification.vendor
  json.certificate_name(certification.certificate.name) if certification.certificate
end
json.partial! '/shared/industry_and_position', parent: @profile
