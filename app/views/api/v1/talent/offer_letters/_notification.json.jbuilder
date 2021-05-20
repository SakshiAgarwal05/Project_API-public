json.(notification, :id, :created_at, :updated_at, :message, :user_agent)

from = notification.from
if from && from.is_a?(User)
  json.from from, :id, :cs_email, :username, :first_name, :last_name
elsif from && from.is_a?(Talent)
  json.from from, :id, :email, :name, :first_name, :last_name
end