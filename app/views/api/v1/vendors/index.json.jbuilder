json.data do
  json.array! @vendors do |vendor|
    json.(vendor, :id, :name)
  end
end