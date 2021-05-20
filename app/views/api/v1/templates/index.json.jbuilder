json.data do
  json.array! @templates do |template|
    json.(template, :id, :name)
  end
end