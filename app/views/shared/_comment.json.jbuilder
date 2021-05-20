json.call(note,
          :id,
          :note,
          :created_at,
          :visibility,
          :announcement)

json.user(note.user,
          :id,
          :avatar,
          :image_resized,
          :first_name,
          :last_name,
          :username,
          :primary_role,
          :role_group) if note.user

json.mentioned note.mentioned do |user|
  json.call(user,
            :id,
            :avatar,
            :image_resized,
            :first_name,
            :last_name,
            :username,
            :primary_role,
            :role_group)
end

json.talent_job do
  json.call(note.notable, :id, :rejected, :stage, :withdrawn)
  json.job(note.notable.job, :id, :title, :display_job_id)
  json.client(note.notable.client, :id, :company_name)
  json.talent(note.notable.talent, :id, :email, :city, :first_name, :last_name)
end

json.read note.read_value

json.tag note.note_status
