json.industries parent.industries do |industry|
  json.(industry, :id, :name,)
end
json.positions parent.positions do |position|
  json.(position, :id, :name,)
end
