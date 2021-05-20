json.data do
  json.array! events do |event|
    json.partial! 'admin/events/list', event: event
  end
end
