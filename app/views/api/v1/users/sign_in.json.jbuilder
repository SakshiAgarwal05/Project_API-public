json.partial! "#{@user.class.table_name}/detail", resource: @user

json.sign_in_count @user.sign_in_count
json.dashboard_permissions dashboard_permissions
json.client_app_dashboard_permissions client_app_dashboard_permissions
json.auth_token @user.auth_token(current_user&.id)

json.impersonater get_impersonater

if @user.timezone
  json.timezone(
    @user.timezone,
    :id,
    :name,
    :value,
    :abbr,
    :if_dst,
    :dst_start_day,
    :dst_end_day,
    :dst_start_date,
    :dst_end_date
  )
else
  json.default_timezone(
    @user.default_timezone,
    :id,
    :name,
    :value,
    :abbr,
    :if_dst,
    :dst_start_day,
    :dst_end_day,
    :dst_start_date,
    :dst_end_date
  )
end

json.job_types @user.job_types
json.total_jobs @user.jobs.count

if @user.agency_user?
  agency = @user.agency

  json.skills @user.skills, :id, :name
  json.industries @user.industries, :id, :name
  json.categories @user.categories, :id, :name
  json.countries @user.countries, :id, :name, :abbr

  stats = @user.detail_statistics('all')
  json.total_sourced stats['sourced'] || 0
  json.total_invited stats['invited'] || 0
  json.total_submitted stats['submitted'] || 0
  json.total_applied stats['applied'] || 0
  json.total_hired stats['hired'] || 0
  json.total_interviewed stats['interviewed'] || 0
  json.total_disqualified stats['disqualified'] || 0
  json.total_active_jobs stats['jobs_count'] || 0
  json.total_candidates_added @user.created_talents.count
  json.total_candidates_saved @user.profiles.my_candidates.count
  json.tnc @user.tnc
  json.restrict_access @user.restrict_access

  org_stats = agency.detail_statistics('all')
  json.org_sourced org_stats['sourced'] || 0
  json.org_invited org_stats['invited'] || 0
  json.org_submitted org_stats['submitted'] || 0
  json.org_applied org_stats['applied'] || 0
  json.org_interview org_stats['interviewed'] || 0
  json.org_hired org_stats['hired'] || 0
  json.org_disqualified org_stats['disqualified'] || 0
  json.org_active_jobs org_stats['jobs_count'] || 0
  json.org_total_jobs agency.agency_jobs.count
  json.org_candidates_added agency.org_created_talents.count
  json.org_candidates_saved agency.org_saved_talents.count
  json.org_restrict_access agency.restrict_access
  json.org_type agency.agency_type
  json.org_tnc_accepted_count agency.tnc_accepted_count

  json.org_first_seen agency.owner&.confirmed_at
  json.active_recruiters_count agency.active_recruiters_count

  if agency.restrict_access?
    incumbents = agency.accessibles.incumbents.includes(:client)
    if incumbents.exists?
      json.incumbent_clients do
        json.array! incumbents do |incumbent|
          json.call incumbent.client, :id, :company_name
        end
      end
    end
  end
end

if current_user
  json.total_unread_messages current_user.notifications.where(read: false).count
end

json.blank_fields @user.incompleted_profile

json.agency_user @user.agency_user?

json.enterprise_user @user.hiring_org_user?

json.unread_inbox_messages Receiver.inbox_messages(@user.id).where(open_via: nil).group_by(&:parent_id).count if @user.internal_user?
json.applicant_indicator_count Shareable.unacknowledged_applicants(@user.id).count
