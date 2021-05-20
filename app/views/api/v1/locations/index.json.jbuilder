json.array! @locations do |industry|
  json.(industry, :id, :city, :state, :country, :address)
end
