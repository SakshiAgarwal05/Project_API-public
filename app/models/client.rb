class Client < ApplicationRecord
  acts_as_paranoid
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include AddressValidations
  include AddAbility
  include GlobalID::Identification

  include Fields::FieldsClient
  include CallbackResizeImage
  include Constants::ConstantsClient
  include Validations::ValidationsClient
  include ModelCallback::CallbacksClient
  include Scopes::ScopesClient
  include ES::ESClient
  include Notifiable
  include CurrentUser

  HUMANIZED_ATTRIBUTES = {
    msp_name: "MSP name",
    vms_platform: "VMS platform",
    ats_platform: "ATS platform"
  }

  class << self
    def human_attribute_name(attr, options = {})
      HUMANIZED_ATTRIBUTES[attr.to_sym] || super
    end

    def reassign(primary, assigned_user, re_assign_user)
      all.to_a.each do |client|
        client.re_assign_cs_user(primary, assigned_user, re_assign_user)
      end

      ReassignToJob.set(wait: 10.seconds).perform_later(assigned_user, re_assign_user, all.to_a)
    end
  end

  def beeline_billing_term
    Rails.cache.fetch("beeline_ho_billing_term_for_client_#{id}", expires_in: 1.month) do
      billing_terms.where(hiring_organization_id: HiringOrganization.beeline&.id).first
    end
  end

  def if_saved(user=nil)
    user ||= LoggedinUser.current_user
    return false if user.nil?
    user.agency_user? ? saved_by_ids.include?(user.id) : if_my_client(user)
  end

  # count number of active jobs
  def active_jobs_count
    self.jobs.complete_valid_jobs.count
  end

  def new_jobs_count
    jobs.new_jobs.count
  end

  def recruiters_working(login_user)
    recruiter_ids = RecruitersJob.
      where(status: 'saved', job_id: job_ids).
      select(:user_id).
      distinct

    User.visible_to(login_user).where(id: recruiter_ids)
  end

  def client_my_tabs(user)
    return {} unless if_my_client(user)
    Hash[user.all_permissions['my client tabs'].collect{|x| [x.downcase.gsub(' ', '_').to_sym, true]}]
  end

  def client_message_options(user)
    user.all_permissions['client message user roles'] || []
  end

  # IFDEPRICATED
  def bulk_assign_recruiters(user_ids=[], current_user)
    users = User.visible_to(current_user).find(user_ids.uniq)
    to_add = users - self.saved_by.visible_to(current_user)

    to_add.each do |u|
      self.saved_by.push(u)
    end
    self.save(validate: false)
  end

  # IFDEPTICATED
  def bulk_remove_recruiters(user_ids = [], current_user)
    users = User.visible_to(current_user).find(user_ids.uniq)
    to_remove = saved_by.visible_to(current_user) & users

    if to_remove.empty?
      errors.add(:base, "This recruiter can not be removed as he has saved few jobs for this client.")
      return false
    end

    to_remove.each do |u|
      saved_by.delete(u)
    end
    save(validate: false)
  end

  def account_managers
    assignables.account_manager
  end

  def onboarding_agents
    assignables.onboarding_agent
  end

  def supervisors
    assignables.supervisor
  end

  def primary_account_manager
    account_managers.primary.first&.user
  end

  def primary_onboarding_agent
    onboarding_agents.primary.first&.user
  end

  def primary_supervisor
    supervisors.primary.first&.user
  end

  def is_account_manager?(user)
    account_managers.for_user(user.id).any?
  end

  def is_onboarding_agent?(user)
    onboarding_agents.for_user(user.id).any?
  end

  def is_supervisor?(user)
    supervisors.for_user(user.id).any?
  end

  def active_jobs
    jobs.where.not(stage: Job::STAGES_FOR_CLOSED).for_adminapp
  end

  def active_recruiters
    # TODO: Research time. avoice interpolation
    User.left_outer_joins(saved_clients_users: {user: :agency}, recruiters_jobs: {user: :agency}).
      where("
        affiliates.job_id in (#{jobs.open_jobs.select(:id).to_sql}) OR
        saved_clients_users.client_id = ? AND
        users.locked_at is NULL AND
        agencies.locked_at is null", id).
      distinct
  end

  def active_recruiters_ids
    active_recruiters.pluck(:id)
  end

  def assign_user(primary, role, user)
    result = {}
    return result if user.assignables.for_client(id).any?
    if user.primary_role.eql?(role)
      assignables.create(
        user: user,
        role: role.parameterize.underscore,
      )

      assign_primary_user(user) if primary
    else
      result[:errors] = 'Invalid or Unverified user.'
    end
    result
  end

  # Re assign CS internal user. AM/OBA/Supervisor.
  def re_assign_cs_user(primary, assigned_user, re_assign_user)
    result = {}
    role = re_assign_user.primary_role
    is_role_match = assigned_user.primary_role.eql?(role) && re_assign_user.primary_role.eql?(role)
    if is_role_match && role.eql?('account manager')
      active_jobs.where(account_manager_id: assigned_user.id)
                 .update_all(account_manager_id: re_assign_user.id)
    elsif is_role_match && role.eql?('onboarding agent')
      active_jobs.where(onboarding_agent_id: assigned_user.id)
                 .update_all(onboarding_agent_id: re_assign_user.id)
    elsif is_role_match && role.eql?('supervisor')
      active_jobs.where(supervisor_id: assigned_user.id)
                 .update_all(supervisor_id: re_assign_user.id)
    else
      result[:errors] = 'Assigned/Re-assign user role not matched'
    end
    create_assignable(re_assign_user, role, primary) if result.empty?
    result
  end

  def create_assignable(cs_user, role, primary)
    existing_src = cs_user.assignables.for_client(id)
    existing_src.create(role: role.parameterize.underscore) if existing_src.empty?
    assign_primary_user(cs_user) if primary
  end

  def assign_primary_user(user)
    existing_primary = assignables.primary.
      where(role: user.primary_role.parameterize.underscore)
    existing_primary.update_all(is_primary: false) if existing_primary.any?
    assignables.for_user(user).update_all(is_primary: true)
  end

  def remove_assigned_user(user, note, current_user)
    result = {}
    role = user.primary_role.parameterize.underscore
    if assignables.primary.where(user: user, role: role).empty?
      assignables.for_user(user).delete_all
      removed_history(user, note, current_user)
    else
      result[:errors] = "Please make primary #{user.primary_role} to other before remove!"
    end
    result
  end

  def primary?(user)
    assignables.for_user(user).primary.any?
  end

  def working_active_jobs(user)
    case user.primary_role
    when 'account manager'
      active_jobs.where(account_manager_id: user.id)
    when 'onboarding agent'
      active_jobs.where(onboarding_agent_id: user.id)
    when 'supervisor'
      active_jobs.where(supervisor_id: user.id)
    end
  end

  # AM/Supervisor representing talents
  def representing_talents(user)
    user.talents_jobs.active
  end

  def reassign_power(user)
    user.can?(:reassign_account_manager, self) ||
    user.can?(:reassign_onboarding_agent, self) ||
    user.can?(:reassign_supervisor, self)
  end

  def set_primary_power(user)
    user.can?(:assign_primary_am, self) ||
    user.can?(:assign_primary_oba, self) ||
     user.can?(:assign_primary_supervisor, self)
  end

  def set_remove_power(user)
    user.can?(:remove_account_manager, self) ||
    user.can?(:remove_onboarding_agent, self) ||
    user.can?(:remove_supervisor, self)
  end

  def removed_history(user, note, current_user)
    rejected_histories.create(
      rejection_note: note,
      rejected_by: current_user,
      rejected_to: user,
      created_at: Time.zone.now,
      updated_at: Time.zone.now
    )
  end

  def if_my_client(user)
    case user.all_permissions['my clients']
    when 'all'
      true
    when 'assigned'
      return is_supervisor?(user) if user.supervisor?
      return is_account_manager?(user) if user.account_manager?
      return is_onboarding_agent?(user) if user.onboarding_agent?
    when 'saved by org'
      user.agency_user? ? saved_by.where(id: user.my_agency_users.pluck(:id)).any? : false
    when 'saved by team'
      user.agency_user? ? saved_by.where(id: user.my_team_users.pluck(:id)).any? : false
    when 'saved'
      user.agency_user? ? saved_by.find(user.id) : false
    else
      false
    end
  end

  def if_visible_to(user)
    case user.all_permissions['clients']
    when 'all'
      true
    when 'assigned'
      return is_supervisor?(user) if user.supervisor?
      return is_account_manager?(user) if user.account_manager?
      return is_onboarding_agent?(user) if user.onboarding_agent?
    when 'public'
      true
    else
      false
    end
  end

  def my_staffing_ids
    staffing_ids = hiring_organization_ids +
                   billing_terms.pluck(:hiring_organization_id)
    staffing_ids.uniq
  end

  def cs_active_jobs_count
    jobs.complete_valid_jobs.only_published_to_cs.count
  end

  def performance_total(user = nil)
    tjs = user.present? ? talents_jobs.visible_to(user) : talents_jobs
    metrics_stages.
      where(talents_job_id: tjs.select(:id)).
      group(:stage).
      count
  end

  def client_related_objs
    { client: { id: id, logo: logo, company_name: company_name }}
  end
end
