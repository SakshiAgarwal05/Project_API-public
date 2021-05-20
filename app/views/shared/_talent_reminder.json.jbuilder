json.call(
  reminder,
  :id,
  :unit,
  :duration_period,
  :note,
  :status,
  :created_at,
  :updated_at,
  :reminder_at
)

if reminder.user.present?
  json.user do
    json.call(
      reminder.user,
      :id,
      :first_name,
      :last_name,
      :avatar,
      :image_resized,
      :email,
      :username
    )
  end
end

if reminder.created_by.present?
  json.created_by do
    json.call(
      reminder.created_by,
      :id,
      :first_name,
      :last_name,
      :avatar,
      :image_resized,
      :email,
      :username
    )
  end
end

if reminder.tagged_users.exists?
  json.tagged_users reminder.tagged_users,
                    :id,
                    :first_name,
                    :last_name,
                    :avatar,
                    :image_resized,
                    :email,
                    :username
end
