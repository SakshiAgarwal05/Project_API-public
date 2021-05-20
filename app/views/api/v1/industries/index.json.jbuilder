json.call @industries do |industry|
  json.call(industry, :name, :id)
end
