class User < ApplicationRecord
  acts_as_paranoid
  extend Devise::Models
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include AllUser
  include AddAbility
  include GlobalID::Identification
  include AddressValidations

  include CustomDevise

  include Fields::FieldsUser
  include CallbackResizeImage
  include Validations::ValidationsUser
  include ES::ESUser
  include ModelCallback::CallbacksUser
  include Scopes::ScopesUser
  include Notifiable
  include CurrentUser
  include Concerns::Addressable
  include Concerns::RecruitersScores
  include Concerns::CommonCsmmCallbacks

  # checks if a role is assigneed to user or not?
  [
    'super admin',
    'admin',
    'onboarding agent',
    'job sourcing agent',
    'account manager',
    'agency owner',
    'agency admin',
    'team admin',
    'team member',
    'talent sourcing agent',
    'supervisor',
    'finance agent',
    'client admin',
    'hiring mamager',
    'customer support agent',
    'enterprise owner',
    'enterprise admin',
    'enterprise manager',
    'enterprise member',
  ].each do |r|
    method_name = r.tr(' ', '_')
    define_method "#{method_name}?" do
      primary_role == r
    end
  end

  def self.es_includes(options = {})
    [
      :agency,
      :hiring_organization,
    ]
  end

  def self.beeline
    Rails.cache.fetch("beeline_user", expires_in: 1.month) do
      find_by_username('Beeline')
    end
  end

  def self.crowdstaffing
    Rails.cache.fetch("crowdstaffing_user", expires_in: 1.month) do
      find_by_username('Crowdstaffing')
    end
  end

  def self.new_internal_user
    new(role_group: 1)
  end

  def self.new_agency_user
    new(role_group: 2)
  end

  def self.new_enterprise_user
    new(role_group: 3)
  end

  def self.search_users(params, user)
    search = ES::SearchUser.new(params, user)
    search.search_users
  end

  def any_opportunity_saved?
    distributions.as_opportunities.where(status: 'saved').any?
  end

  def front_end_host
    if hiring_org_user? && ['development', 'test'].exclude?(Rails.env)
      return FE_HOST.gsub(/app\./, 'enterprise.')
    end

    if internal_user? && ['development', 'test'].exclude?(Rails.env)
      return FE_HOST.gsub(/enterprise\./, 'app.')
    end

    return FE_HOST unless agency_user?
    host = Rails.cache.read("front_end_admin_host_#{agency_id}")

    login_url = agency.login_url
    return FE_HOST unless login_url
    login_url = login_url.split('.').insert(1, Rails.env).join('.') unless Rails.env.production?

    return host if host
    dns_setup = !!Socket.getaddrinfo(login_url, "http", nil, :STREAM) rescue nil
    if dns_setup
      host = 'https://' + login_url
      Rails.cache.write("front_end_agency_host_#{agency_id}", host, expires_in: 1.month)
      if %w(uat demo).include?(Rails.env)
        return FE_HOST.gsub("https://app.#{Rails.env}.crowdstaffing.com", host)
      else
        host
      end
    else
      FE_HOST
    end
  end

  def all_permissions
    (PERMISSIONS[primary_role] || {}).merge(custom_permissions)
  end

  def my_jobs_permissions
    all_permissions['actions my jobs']
  end

  def internal_user?
    role_group.eql?(1)
  end

  def agency_user?
    role_group.eql?(2)
  end

  def is_agency_owner?
    agency.owner == self
  end

  def hiring_org_user?
    role_group.eql?(3)
  end

  def hiring_org_owner
    primary_role.eql?('enterprise owner')
  end

  def my_team_users
    User.my_teams_users(self)
  end

  def my_agency_users
    User.where(agency_id: agency_id)
  end

  # unsave a job
  def unsave(job)
    errors.add(:base, "Job creator can't unsave this job") if id.eql?(job.created_by_id)
    active_candidates = job.talents_jobs.where(user_id: id).active.count

    if active_candidates > 0
      errors.add(
        :base,
        "You cannot remove this job as you have #{active_candidates} candidates which are still active."
      )
    end
    saved_job = affiliates.saved.for_job(job.id).last
    if errors.blank? && saved_job
      saved_job.update_attributes(status: 'unsaved', updated_at: Time.now)
      ReindexObjectJob.set(wait: 10.seconds).perform_later(job)
    else
      false
    end
  end

  def my_managed_client_subquery
    assignables.account_manager.select(:client_id)
  end

  def my_supervisord_client_subquery
    assignables.supervisor.select(:client_id)
  end

  def my_onboard_client_subquery
    assignables.onboarding_agent.select(:client_id)
  end

  def my_supervisord_client_ids
    my_supervisord_client_subquery.pluck(:client_id)
  end

  def my_managed_client_ids
    my_managed_client_subquery.pluck(:client_id)
  end

  def my_onboard_client_ids
    my_onboard_client_subquery.pluck(:client_id)
  end

  # A team_member's all possible admins who will
  # receive their activity notification.
  def team_members_admins
    return [] unless team_member?
    ta = teams.collect { |team| team.users.team_admins.ids }.flatten
    User.where(agency_id: agency_id, primary_role: ['agency owner', 'agency admin']).
      or(User.where(id: id)).
      or(User.where(id: ta))
  end

  # A team admin's all possible admins who will
  # receive their activity notification.
  def team_admins_admins
    return [] unless team_admin?
    User.where(agency_id: agency_id, primary_role: ['agency owner', 'agency admin']).
      or(User.where(id: id))
  end

  def type(job)
    if agency&.restrict_access?
      agency&.invited_for(job)&.incumbent? ? 'Incumbent' : 'Limited'
    else
      'Open'
    end
  end

  def limited_access?
    agency && agency.restrict_access?
  end
  # A agency admin's all possible admins who
  # will receive their activity notification.
  def agency_admins_admins
    return [] unless agency_owner_admin?
    agency.users.where(primary_role: ['agency admin', 'agency owner'])
  end

  def account_manager_admins
    [self, User.admins, User.super_admins].flatten
  end

  def supervisor_admins
    [self, User.admins, User.super_admins].flatten
  end

  def find_admins
    return team_members_admins if team_member?
    return team_admins_admins if team_admin?
    return agency_admins_admins if agency_owner_admin?
    return account_manager_admins if account_manager?
    return supervisor_admins if supervisor?
    return hiring_organization.users if hiring_org_user?
    User.super_admins
  end

  def transfer_rtr(reassign_user, options = {})
    return true if reassign_user.id.eql?(id)

    assoc_tjs = TalentsJob.where(user_id: id).active
    assoc_tjs = assoc_tjs.where(id: options[:talent_job_id]) if options[:talent_job_id].present?
    assoc_tjs = assoc_tjs.where(job_id: options[:jobs_ids]) if options[:jobs_ids].present?
    assoc_tjs = assoc_tjs.where(talent_id: options[:talent_ids]) if options[:talent_ids].present?

    assoc_tjs.each do |tj|
      tj.user_id = reassign_user.id
      tj.agency_id = reassign_user.agency_id
      tj.save(validate: false)
    end

    if options[:jobs_ids].present?
      options[:jobs_ids].each do |job_id|
        job = Job.find(job_id)
        next if job.picked_by.include?(reassign_user)
        if TalentsJob.where(user_id: id, job_id: job_id).active.empty?
          job.recruiters_jobs.for_user(id).delete_all
        end

        affiliate_record = job.recruiters_jobs.find_by(user: reassign_user)
        if affiliate_record.blank?
          recruiters_job = job.recruiters_jobs.find_or_initialize_by(
            user_id: reassign_user.id,
            status: 'saved',
            saved_from: 'rtr transfer'
          )
          recruiters_job.save(validate: false)
        else
          affiliate_record.update_attributes(status: 'saved', saved_from: 'rtr transfer')
        end
      end
    end
  end

  def active_jobs_count
    jobs.complete_valid_jobs.count
  end

  def representing_talents(job)
    talents_jobs.where(job_id: job.id).not_withdrawn
  end

  def total_representing_talents(job)
    talents_jobs.where(job_id: job.id)
  end

  def can_update_email?
    super_admin? || admin? || customer_support_agent? || supervisor?
  end

  def get_status
    return 'Disabled' unless enable
    if !confirmed?
      return 'Opened' if confirmation_sent_at && confirmation_status?
      return 'Invited' if confirmation_status.is_false?
    end
    return 'Active' if enable
    'Disabled'
  end

  # TODO: helpers is the best place for this methodf
  def detail_statistics(stats_by)
    min_job_published_time = Job.saved_by_me(self).pluck(:published_at).compact.min

    query =
      if account_manager?
        TalentsJob.where(job_id: managed_job_ids)
      else
       TalentsJob.where(
        agency_id: agency_id,
        user_id: id,
        job_id: Job.saved_by_me(self).active_jobs.pluck(:id)
      )
     end

    time = filter_time(stats_by) {
      if account_manager?
        managed_jobs.pluck(:published_at).compact.min || created_at
      else
        min_job_published_time || created_at
      end
    }

    from_time, to_time = time['from_time'], time['to_time']

    metric_filter = query.joins(:metrics_stages).
      where({ metrics_stages: { updated_at: (from_time..to_time) } })

    result = metric_filter.group('lower(metrics_stages.stage)').count
    %w(sourced invited signed submitted applied hired).each do |x|
      result[x] ||= 0 end
    result['disqualified'] = result.delete('rejected') || 0
    result['withdrawn'] = result.delete('withdrawn') || 0
    result['interviewed'] = metric_filter.group('metrics_stages.if_interview').count[true] || 0

    active_jobs = Job.saved_by_me(self).active_jobs

    result['jobs_count'] =
      if account_manager?
        active_jobs.where(published_at: (from_time..to_time)).count
      else
        active_jobs.joins(:recruiters_jobs).
          where(affiliates: { updated_at: (from_time..to_time) }).
          uniq.count
      end

    result
  end

  # For recruiter user & Hiring/enterprise user.
  def incompleted_profile
    if hiring_org_user?
      %I[
        first_name
        last_name
        contact_no
        email
      ].select { |field| try(field).blank? }.map(&:to_s).map(&:humanize)
    elsif agency_user?
      %I[
        job_types
        first_name
        last_name
        emails
        contact_no
        email
        industries
        categories
        countries
      ].select { |field| try(field).blank? }.map(&:to_s).map(&:humanize)
    else
      []
    end
  end

  def bulk_assign_jobs(assoc_jobs)
    assoc_jobs.each do |job|
      next if job.picked_by.include?(self)
      job.agency_ids.push(agency_id)
      affiliate_record = recruiters_jobs.find_by(job: job)
      if affiliate_record.blank?
        recruiters_jobs.create(
          job: job,
          ref: 'assign',
          status: 'saved',
          saved_from: 'assigned by recruiter'
        )
      else
        affiliate_record.update_attributes(
          ref: 'assign',
          status: 'saved',
          saved_from: 'assigned by recruiter'
        )
      end
    end
  end

  def assign_teams(new_team_ids)
    t_ids = (team_ids + new_team_ids).uniq
    update_attributes(team_ids: t_ids)
  end

  def reassign_team(assigned_team, reassign_team)
    teams.delete(assigned_team)
    teams.push(reassign_team)
  end

  def remove_team(team)
    teams.delete(team)
    return true if team_member? || agency_owner_admin? || teams.any?
    update_attributes(primary_role: 'team member')
  end

  def account_managers_picker
    ams = User.account_managers.verified
    case primary_role
    when 'admin', 'super admin'
      ams
    when 'supervisor'
      ams.joins(:assignables).
        where(assignables: { client_id: my_supervisord_client_ids }).
        distinct
    when 'account manager'
      ams.joins(:assignables).
        where(assignables: { client_id: my_managed_client_ids }).
        where.not(id: id).
        distinct
    else
      User.none
    end
  end

  # TODO: should be defined in permissions
  def am_picker_permitted?
    ['super admin', 'admin', 'supervisor', 'account manager'].include?(primary_role)
  end

  # TODO: should be defined in permissions
  def recruiters_picker_permitted?
    agency_user?
  end

  def active_recommend
    distributions.active
  end

  def make_primary(assoc_client_ids)
    assignables.
      for_client(assoc_client_ids).
      account_manager.
      primary.
      update_all(is_primary: false)

    assignables.
      where(client_id: assoc_client_ids).
      update_all(is_primary: true)

    ReindexObjectJob.
      perform_now(Buyer.where(id: assoc_client_ids).to_a)
  end

  def remove_clients(assoc_client_ids, current_user, note)
    assoc_jobs = managed_jobs.where(client_id: assoc_client_ids).
      where.not(stage: Job::STAGES_FOR_CLOSED)

    if assoc_jobs.exists?
      errors.add(
        :base,
        "Cannot remove account manager, #{name}, because they still have jobs assigned to them. First re-assign all jobs and then try"
      )
      false
    else
      assignables.where(client_id: assoc_client_ids).delete_all

      ReindexObjectJob.
        perform_now(Buyer.where(id: assoc_client_ids).to_a)

      RejectedHistory.bulk_create(assoc_client_ids, current_user, self, note)
    end
  end

  def intercom_user_hash
    OpenSSL::HMAC.hexdigest('sha256', ENV['INTERCOM_APP_SECRET'], id.to_s) rescue nil
  end

  # get latest invitation for particular job
  def latest_invite_for_job(job_id)
    invitations.for_job(job_id).last
  end

  def latest_csmm_invite_for_job(job_id)
    distributions.active.for_job(job_id).last
  end

  def saved_active_jobs
    Job.saved_by_me(self).where(stage: Job::STAGES_FOR_APPLICATION)
  end

  def inactive_jobs
    jobs.inactive.by_recruiter(self)
  end

  def archive_jobs
    inactive_jobs.
      joins("LEFT JOIN talents_jobs on talents_jobs.job_id = jobs.id").
      where("talents_jobs.rejected = false AND talents_jobs.withdrawn = false AND talents_jobs.user_id = '#{id}'").
      distinct
  end

  def remove_jobs
    inactive_jobs.where.not(id: archive_jobs.select('jobs.id'))
  end

  def exists_in_opportunities(job)
    Job.invited_jobs_for(self).where(id: job.id).exists?
  end

  def tnc_accept_notification
    notifications.where(label: "terms and conditions accepted").first
  end

  def invitation_viewed_notification
    Notification.where(label: "Member opened invitation", object: self).first
  end

  def invited_notification
    Notification.where(label: "New member to agency", object: self).first
  end

  def agency_users_for_bill_rate(user)
    return false if user.blank?
    agency.present? && agency_id.eql?(user.agency_id)
  end

  def enterprise_users_for_bill_rate(user)
    return false if user.blank?
    hiring_organization.present? && hiring_organization_id.eql?(user.hiring_organization_id)
  end

  def internal_users_for_bill_rate(job)
    return false if job.blank?
    self == job.account_manager || self == job.supervisor || super_admin? || admin?
  end

  # def check_crowdstaffer_url(domain)
  #   if role_group.eql?(3)
  #     domain.eql?(FE_HOST.gsub(/app\./, 'enterprise.'))
  #   else
  #     !domain.eql?(FE_HOST.gsub(/app\./, 'enterprise.'))
  #   end
  # end

  def default_timezone
    Timezone.find_by(name: "Pacific Standard Time")
  end

  def sd_score(job_id)
    begin
      sd_scores.where(job_id: job_id).maximum(:score).to_f
    rescue
      return 0
    end
  end

  def my_group_users
    User.
      left_outer_joins(:groups).
      where(id: id, groups: { id: group_ids }).
      distinct
  end

  def agency_owner_admin?
    agency_admin? || agency_owner?
  end

  def enterprise_owner_admin?
    enterprise_admin? || enterprise_owner?
  end

  def account_type
    if internal_user?
      'CROWDSTAFFING'
    elsif agency_user?
      'TALENT SUPPLIER'
    elsif hiring_org_user?
      'HIRING ORGANIZATION'
    end
  end

  def update_shared_jobs_status(status, options)
    return if !options[:bulk].is_true? && options[:job_ids].blank?

    updatable_affiliates = affiliates.saved.joins(:job).
      joins("LEFT JOIN talents_jobs on
          jobs.id = talents_jobs.job_id and
          talents_jobs.rejected = false and
          talents_jobs.withdrawn = false and
          talents_jobs.user_id = affiliates.user_id
        ").where(jobs: {stage: 'Closed'})

    if options[:job_ids].present?
      updatable_affiliates = updatable_affiliates.where(job_id: options[:job_ids])
    end

    if status.eql?('archived')
      updatable_affiliates = updatable_affiliates.where.not(talents_jobs: {id: nil}).distinct
      status = 'archived'
    else
      updatable_affiliates = updatable_affiliates.where(talents_jobs: {id: nil}).distinct
      status = 'removed'
    end
    updatable_job = updatable_affiliates.includes(:job).collect(&:job)

    updatable_affiliates.update_all(status: status, updated_at: Time.now)

    updatable_job.each do |job|
      ReindexObjectJob.set(wait: 3.seconds).perform_later(job)
    end
  end

  def user_related_objs
    { user: { id: id, email: email, avatar: avatar, last_name: last_name, first_name: first_name }}
  end

  def statistics_tile_stages
    onboarding_agent? ? PipelineStep::OBA_STAGES : PipelineStep::STATISTICS_TILE_STAGES
  end

  def incumbent?(job)
    agency&.invited_for(job)&.incumbent?
  end

  def comments_notifications
    read_notes.talents_jobs
  end

  def mentioned_notes
    mentioned_notes_users.select(:note_id)
  end

  def direct_comments
    comments_notifications.where(id: mentioned_notes)
  end

  def watchlist_comments
    comments_notifications.where.not(id: mentioned_notes)
  end

  def read_comments(is_mentioned)
    read_notes_users.where(is_mentioned: is_mentioned, resource_type: 'TalentsJob')
  end

  def unread_comments_count
    unreads = read_notes_users.where(read: false, resource_type: 'TalentsJob')
    {
      unread: unreads.count,
      unread_direct: unreads.where(is_mentioned: true).count,
      unread_watching: unreads.where(is_mentioned: false).count,
    }
  end

  def active_login
    show_status == "Active" && incompleted_profile.blank?
  end
end
