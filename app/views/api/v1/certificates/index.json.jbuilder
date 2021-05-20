json.data do
  json.array! @certificates do |certificate|
    json.(certificate, :id, :name)
  end
end
