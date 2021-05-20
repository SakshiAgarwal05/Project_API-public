json.(
  resource,
  :id,
  :avatar,
  :id,
  :password_set_by_user,
  :email,
  :cs_email,
  :contact_no,
  :username,
  :first_name,
  :last_name,
  :headline,
  :country,
  :country_obj,
  :state,
  :state_obj,
  :city,
  :bio,
  :address,
  :postal_code,
  :job_types,
  :confirmed?,
  :primary_role,
  :role_group,
  :agency_id,
  :image_resized,
  :tnc,
  :restrict_access,
  :profile_tnc_accepted_at,
  :extension,
  :viewed_invite,
  :confirmation_status,
  :email_signature
)

json.is_org_member resource.team_admin? || resource.team_member?

json.phones resource.phones do |phone|
  json.call(phone, :id, :type, :number, :primary, :confirmed)
end

json.emails resource.emails do |email|
  json.call(email, :id, :type, :email, :primary)
end

json.incompleted_profile resource.incompleted_profile.any?

json.intercom_user_hash resource.intercom_user_hash

if resource.agency
  json.agency(
    resource.agency,
    :id,
    :company_name,
    :logo,
    :website,
    :login_url,
    :country,
    :country_obj,
    :state,
    :state_obj,
    :city,
    :postal_code,
    :contact_number,
    :summary,
    :if_valid,
  )
end

if resource.hiring_organization
  json.hiring_organization(
    resource.hiring_organization,
    :id,
    :company_relationship,
    :company_relationship_name,
    :website,
    :logo,
    :image_resized,
    :address,
    :city,
    :state,
    :country,
    :state_obj,
    :country_obj,
    :postal_code,
    :confirmed
  )

  json.is_assigned_jobs (resource.enterprise_manager? || resource.enterprise_member?) && resource.ho_jobs_watchers.exists?
end
