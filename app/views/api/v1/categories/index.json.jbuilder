debugger
json.array! @categories do |category|
  json.(category, :name, :id)
end

