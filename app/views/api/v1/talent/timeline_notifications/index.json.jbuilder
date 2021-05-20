json.data do
  json.array! @notifications do |notification|
    json.(notification, :id, :created_at, :updated_at, :message, :user_agent)
    json.from notification.from, :id, :cs_email, :username, :first_name, :last_name if notification.from
  end
end