json.data do
  json.array! @receivers.includes(:message) do |receiver|
    json.id receiver.parent_id
    json.open_via receiver.open_via
    json.viewable_information receiver.viewable_information
    json.sendgrid_status receiver.sendgrid_status
    json.created_at receiver.created_at
    json.featured receiver.featured

    message = receiver.message
    json.subject message.subject
    json.body mask_message_body(message)
    json.message_id message.id
  end
end

json.partial! 'pagination/pagination', obj: @receivers, total_count: @total_count
