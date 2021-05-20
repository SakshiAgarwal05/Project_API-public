require 'csmm/match_maker'
require 'csmm/smart_distribution'

class Job < ApplicationRecord
  acts_as_paranoid
  include AddEnableField
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include AddressValidations
  include AddAbility
  include Billing
  include GlobalID::Identification
  include Fields::FieldsJob
  include Constants::ConstantsJob
  include Validations::ValidationsJob
  include ModelCallback::CallbacksJob
  include Notifiable
  include Scopes::ScopesJob
  include ES::ESJob
  include CurrentUser
  include Concerns::Addressable
  include Concerns::JobRecruiters
  include Concerns::JobListingTabValues
  include BeelineJob
  include Dateable
  include Concerns::EnterpriseJobListing
  include Metrics::JobMetrics
  include Concerns::CommonCsmmCallbacks

  cattr_accessor :for_team
  cattr_accessor :team_member

  class << self
    def es_includes(options = {})
      [
        :client,
        :account_manager,
        :supervisor,
        :onboarding_agent,
        :hiring_organization,
        :timezone,
        :industry,
        :category,
        :skills,
        :agencies,
        ho_jobs_watchers: :user,
        affiliates: :user,
      ]
    end

    def convert_to_hours
      { hours: 1, days: 8, months: 160, years: 1920 }
    end

    def convert_to_days
      { hours: (1 / 8.0), days: 1, months: 20, years: 240 }
    end

    def convert_to_months
      { hours: (20 / 1920.0), days: (1 / 20.0), months: 1, years: 12 }
    end

    def convert_to_years
      { hours: (1 / 1920.0), days: (1 / 240.0), months: (1 / 12.0), years: 1 }
    end

    def multiple(input_period, output_period)
      output_period = output_period.to_s.pluralize
      return 0 unless %(hours days months years).include?(output_period)
      send("convert_to_#{output_period}")[input_period.to_s.pluralize.to_sym].to_f || 0
    end

    def human_attribute_name(attr, options = {})
      Job::HUMANIZED_ATTRIBUTES[attr.to_sym] || super
    end

    def new_opportunities(candidate)
      Job.candidate_opportunities(candidate, true)
    end

    def search_jobs(params, user)
      search = ES::SearchJob.new(params, user)
      result = search.search_jobs
      result << search.warning
    end

    def autocomplete_jobs(params, user)
      search = ES::SearchJob.new(params, user)
      search.autocomplete_jobs
    end

    def my_jobs_filter(params, user)
      saved_by_me = params[:saved_by_me]
      jobs = saved_by_me ? Job.saved_by_me(user) : Job.my_jobs(user)
      jobs = jobs.where(stage: params[:stage])

      if user.role_group == 1 && params[:account_managers].any?
        jobs = jobs.joins(:account_manager).where("users.username in (?)", params[:account_managers])
      elsif params[:recruiters].any? && user.role_group == 2
        jobs = jobs.joins(:picked_by).where("users.username in (?)", params[:recruiters])
      elsif params[:hiring_managers].any? && user.role_group == 3
        jobs = jobs.left_outer_joins(:hiring_manager, :hiring_watchers).
          where(users: {username: params[:hiring_managers]},
                hiring_watchers_jobs: {username: params[:hiring_managers]})
      end
      if user.role_group == 3
        jobs = jobs.enterprise_sorting(params[:order_field], params[:order], user)
      else
        jobs = jobs.sortit(params[:order_field], params[:order], user)
      end
    end

    def my_jobs_inactive(params, user)
      jobs = Job.my_jobs(user).inactive

      if params[:recruiters].present?
        affiliates = Affiliate.saved.group_jobs_for_users(
          User.verified.where(username: params[:recruiters])
        )

        jobs = jobs.where(id: affiliates.distinct(:job_id).pluck(:job_id))
      end
      jobs.sortit(params[:order_field], params[:order], user)
    end

    def reassign(primary, assigned_user, re_assign_user)
      clients = Client.where(id: select(:client_id)).to_a
      update_all(account_manager_id: re_assign_user.id)

      clients.each do |client|
        client.assignables.find_or_create_by(
          user_id: re_assign_user.id, role: :account_manager, is_primary: primary
        )
      end

      ReassignToJob.set(wait: 10.seconds).perform_later(assigned_user, re_assign_user, clients)
    end
  end

  def agency_websites
    picked_by.joins(:agency).pluck("agencies.website").compact.uniq
  end

  def process_manual_invites_expire_at
    request = job_manual_invite_requests.where('expire_at > ?',
      Time.now
    ).last
    return nil unless request
    request.expire_at
  end

  def similarity_score_last_calculation
    return nil unless job_similarity.present?
    return nil if JobSimilarity.default_allowed_time > job_similarity.updated_at
    job_similarity.updated_at
  end

  def invited_affiliates
    return [] unless stage == 'Open'
    affiliates.all_type_invitations.not_responded.
      active
  end

  def recommended_affiliates
    return [] unless stage == 'Open'
    distributions.not_responded.
      active
  end

  def reward_quality
    # This method is used on POH response endpoint only
    return { quality: 'average', avg: 0, max: 0 } if job_similarity.blank?
    avg = job_similarity.avg_reward
    max = job_similarity.max_reward
    qty = 'average'

    reward = marketplace_reward['min']
    return { quality: 'average', avg: avg, max: max } if reward.blank?
    if (max / 2) <= reward && reward <= max
      qty = 'great'
    elsif avg <= reward && reward <= (max / 2)
      qty = 'good'
    elsif (avg / 2) <= reward && reward <= avg
      qty = 'fair'
    else
      qty = 'average'
    end
    { quality: qty, avg: avg, max: max }
  end

  ALL_STATUS.each do |s|
    method_name = s.gsub(/ /, '_').downcase
    define_method "#{method_name}?" do
      stage == s
    end
  end

  def get_status
    if published_at.nil? && created_by.hiring_org_user?
      ['Under Review', 6]
    elsif published_at.nil?
      ['Draft', 5]
    elsif is_closed?
      ['Closed', 0]
    elsif is_onhold?
      ['On Hold', 2]
    elsif published_at > Time.now
      ['Scheduled', 4]
    elsif enable
      ['Open', 3]
    else
      ['Disabled', 1]
    end
  end

  def update_status
    update_attributes(stage: get_status[0], priority_of_status: get_status[1])
  end

  def auto_hold
    return if is_onhold?
    return unless holdable?
    update_attributes(
      is_onhold: true,
      reason_to_onhold_job: Job::HOLD_UNHOLD_REASON[:AUTO_HOLD_REASON],
      stage: 'On Hold',
      priority_of_status: 2
    )
    SystemNotifications.perform_later(self, 'job_autohold', nil, nil)
  end

  def unhold
    return unless reason_to_onhold_job.eql?(Job::HOLD_UNHOLD_REASON[:AUTO_HOLD_REASON])
    return unless is_onhold?
    return if holdable?
    update_attributes(
      is_onhold: false,
      reason_to_unhold_job: Job::HOLD_UNHOLD_REASON[:AUTO_RESUME_REASON],
      stage: 'Open',
      priority_of_status: 3
    )
    SystemNotifications.perform_later(self, 'job_unhold', nil, nil)
  end

  def holdable?
    max_applied_limit.to_i > 0 && total_active_applied_count >= max_applied_limit.to_i
  end

  def calculate_total_time
    return if duration_period.nil? || pay_period.nil?
    Job.multiple(duration_period.to_sym, pay_period.to_sym) * duration.to_f
  end

  def multiple(input_period, output_period)
    Job.multiple(input_period, output_period)
  end

  def not_closed
    published? && !is_closed?
  end

  # user can unsave a job
  def unsave(user)
    errors.add(:base, "Job creator can't unsave this job") if user == created_by
    number_of_active_candidates = talents_jobs.where(user: user).active.count
    if number_of_active_candidates > 0
      errors.add(
        :base,
        "You cannot remove this job as you have #{number_of_active_candidates}
          candidates which are still active."
      )

    end
    errors.blank? ? picked_by.delete(user) : false
  end

  def total_hired_count
    talents_jobs.reached_at('Hired').count
  end

  def total_applied_count
    talents_jobs.reached_at('Applied').count
  end

  def total_active_applied_count
    talents_jobs.reached_at('Applied').not_rejected.count
  end

  def total_submitted_count
    talents_jobs.reached_at('Submitted').count
  end

  # get count of how many recruites are working on 5this job
  def recruiters_count
    recruiters_jobs.distinct(:user_id).count
  end

  # checks if someone has started working on the job or not.
  def operating(user = nil)
    user ||= LoggedinUser.current_user
    return false if user.blank?
    user.jobs.find(id)
  end

  def if_saved(user = nil)
    user ||= LoggedinUser.current_user
    return false if user.blank?
    user.agency_user? ? picked_by_ids.include?(user.id) : if_my_job(user)
  end

  # get all list of recruitment pipeline states of a job
  def stages_list
    return {} if recruitment_pipeline.nil?
    recruitment_pipeline.pipeline_steps.order(stage_order: 'asc')
  end

  # update how many user has been viewed the job.
  def viewed
    update_column(:no_of_views, ((no_of_views || 0) + 1))
  end

  # checks if job visibility is public or not.
  def complete_valid_job
    enable && published? && published_at <= Time.now &&
      Job::ACTIVE_STAGES.include?(stage)
  end

  # Callback before destroy doesn't work.(It was working but not now).
  # so we need to overwrite the method.
  def destroy
    unless stage.eql?('Closed') # Closed job can be directly destroyed, no need to disable it
      errors.add(:base, 'You need to disable the job.') if enable
    end
    if errors.blank?
      super
    end
  end

  def account_manager_ids
    client.account_managers.pluck :user_id
  end

  def onboarding_agent_ids
    client.onboarding_agents.pluck :user_id
  end

  def supervisor_ids
    client.supervisors.pluck :user_id
  end

  def account_managers
    User.verified.account_managers.where(id: account_manager_ids)
  end

  def onboarding_agents
    User.verified.onboarding_agents.where(id: onboarding_agent_ids)
  end

  def supervisors
    User.verified.supervisors.where(id: supervisor_ids)
  end

  def is_account_manager?(user)
    account_manager_ids.include?(user.id)
  end

  def is_onboarding_agent?(user)
    onboarding_agent_ids.include?(user.id)
  end

  def is_supervisor?(user)
    supervisor_ids.include?(user.id)
  end

  def job_statistics(*steps)
    steps.map do |step|
      count = talents_jobs.by_stage(step, false).count
      { key: step, count: count }
    end
  end

  def applied_count_all
    return 0 if stages_list.blank?
    stages = ['Applied'] + stages_list.where(fixed: false).pluck(:stage_label)
    stages = stages.collect { |s| /^#{s}$/i }
    talents_jobs.not_rejected.not_withdrawn.where(stage: stages).count
  end

  def percentage
    added = recruiters_jobs.saved.where(updated_at: 1.hour.ago..Time.now).count
    deleted = recruiters_jobs.unsaved.where(updated_at: 1.hour.ago..Time.now).count
    total = added - deleted
    total_talent_suppliers = picked_by.verified.count

    # ptts -> previous_total_talent_suplier
    ptts = (total_talent_suppliers - total).zero? ? 1 : (total_talent_suppliers - total)

    percentage = ((total.to_f / ptts.to_f) * 100).floor(2)

    { value: percentage, positive: percentage.positive? }
  end

  def custom_stages
    stages_list.where(fixed: false).pluck(:stage_label)
  end

  def interviw_unread_count_all(current_user)
    return 0 if stages_list.blank?
    custom_stages.
      collect do |stage|
        talents_jobs.
          visible_to(current_user).
          by_stage(stage, false).
          unread_notifications(current_user, stage).count
      end.
      sum
  end

  def existing_talents_jobs(user)
    user.internal_user? ?
      talents_jobs.where(user_id: user.id) :
      talents_jobs.where(agency_id: user.agency_id)
  end

  def matching_candidate_opportunities(user)
    return Talent.none unless CsmmScore.table_exists?

    my_talents = Talent.my_talents(user)
    already_added = existing_talents_jobs(user).select(:talent_id)

    talent_to_ids = CsmmScore.
      where(
        user_id: nil,
        job_id: id,
        score: 0.6..Float::INFINITY
      ).pluck(:talent_id)

    my_talents.
      where(id: talent_to_ids).
      where(
        "talents.state_obj ->> 'name' = ? and talents.country_obj ->> 'name' = ?",
        state_obj['name'],
        country_obj['name']
      ).
      where.not(id: already_added)
  end

  ALL_STAGES.each do |s|
    define_method "is_#{s.gsub(' ', '').downcase}?" do
      stage == s
    end
  end

  # GET similar jobs.
  def similar_jobs
    Job.public_jobs.includes(:client, :skills).references(:client, :skills).
      where.not(id: id).where("skills.id in (?)", skill_ids).
      where("jobs.country = ? OR jobs.type_of_job = ? or location_type = ? OR client_id = ?",
            country, type_of_job, location_type, client_id).
      order('published_at desc')
  end

  %w(country type_of_job location_type).each do |s|
    define_method "check_similar_#{s}" do |jobs, job_object|
      matched_jobs = []
      jobs.each { |job| matched_jobs << job if job.try(s.to_sym).eql?(job_object.try(s.to_sym)) }
      matched_jobs
    end
  end

  def is_bookmarked_by_user(talent = nil, user = nil)
    user ||= LoggedinUser.current_user
    talent ||= Job.current_talent
    return nil if talent.nil? || current_user.nil?
    talents_jobs.where(talent_id: talent.id, user: user).any?
  end

  def is_invited(talent = nil)
    talent ||= current_talent
    return nil unless talent
    talents_jobs.where(talent_id: talent.id).reached_at('Invited').any?
  end

  # REMOVE: after refactoring views
  def candidate_status
    talents_job =
      if LoggedinUser.current_user.is_a?(Talent)
        current_user_talents_job(LoggedinUser.current_user)
      else
        nil
      end

    return nil unless talents_job
    return 'Withdrawn' if talents_job.withdrawn
    talents_job.stage
  end

  # REMOVE: after refactoring views
  def current_user_talents_job(talent = nil)
    talent ||= (LoggedinUser.current_user.is_a?(Talent) ? LoggedinUser.current_user : nil)
    return nil unless talent
    talent.talents_jobs.where(job_id: id).first
  end

  def assigned_recruiters(user)
    picked_by.visible_to(user).verified.order(created_at: :desc).distinct
  end

  def job_my_tabs(user)
    return {} unless if_my_job(user)
    Hash[user.all_permissions['my job tabs'].collect { |x| [x.downcase.gsub(' ', '_').to_sym, true] }]
  end

  def job_message_options(user)
    user.all_permissions['client message user roles'] || []
  end

  def beeline?
    hiring_organization.beeline?
  end

  # TODO: should be moved to service.
  def bulk_assign_recruiters(user_ids = [], current_user)
    users = User.visible_to(current_user).agency_members.where(id: user_ids)
    new_agency_ids = users.where(restrict_access: false).distinct.pluck(:agency_id)
    new_agency_ids += begin
                        users.where(restrict_access: true).
                          select do |user|
                          Job.get_list_by_access(user).find(id)
                        end.distinct.pluck(:agency_id)
                      rescue
                        []
                      end

    (new_agency_ids - agency_ids).each do |p|
      agency_ids.push(p)
    end

    save(validate: false)

    if !(users & picked_by).empty?
      errors.add(
        :picked_by,
        "Job has already been assigned to this recruiter or has been saved by recruiter"
      )
      return false
    end

    users.each do |u|
      next if picked_by.include?(u)
      affiliate_record = recruiters_jobs.find_by(user: u)
      attributes = {
        user: u,
        status: 'saved',
        ref: 'assign',
        saved_from: 'assigned by recruiter',
      }
      if affiliate_record.blank?
        recruiters_jobs.create(attributes)
      else
        affiliate_record.update_attributes(attributes)
      end
    end
    save(validate: false)
  end

  def bulk_remove_recruiters(login_user, recruiter_ids)
    return if recruiter_ids.blank?

    users = User.visible_to(login_user).where(id: recruiter_ids, role_group: 2)
    active_candidates = talents_jobs.active.where(user_id: users.select(:id))

    if active_candidates.exists?
      usernames = users.pluck(:username).join(', ')
      errors.add(
        :base,
        I18n.t('job.error_messages.reassign', usernames: usernames, role: 'recruiter')
      )
      return false
    else
      recruiters_jobs.saved.where(user_id: users.select(:id)).update_all(status: 'unsaved')
      ReindexObjectJob.set(wait: 10.seconds).perform_later(self)
      ReindexObjectJob.set(wait: 10.seconds).perform_later(recruiters_jobs.saved.to_a)
    end
  end

  def send_email_to_recruiter_about_premium_access(user_ids)
    return if user_ids.blank?
    User.where(id: user_ids).find_each do |user|
      JobsMailer.notify_premium_access(user, self).deliver_later
    end
  end

  def find_invitation(invitation_token)
    talents_jobs.find_by(invitation_token: invitation_token)
  end

  def open_job
    stage == 'Open'
  end

  def reopen(reason_to_reopen = nil)
    return errors.add(:base, I18n.t('job.error_messages.reached_max_applied_limit')) if holdable?
    update_attributes(reason_to_reopen: reason_to_reopen, stage: 'Open', priority_of_status: 3)
  end

  def if_my_job(user)
    return false unless user.all_permissions['my jobs']
    case user.all_permissions['my jobs']
    when 'all'
      visible_to_cs?

    when 'assigned clients'
      return visible_to_cs? && is_supervisor?(user) if user.supervisor?
      return visible_to_cs? && is_account_manager?(user) if user.account_manager?
      return visible_to_cs? && is_onboarding_agent?(user) if user.onboarding_agent?

    when 'assigned jobs'
      return visible_to_cs? && supervisor == user if user.supervisor?
      return visible_to_cs? && account_manager == user if user.account_manager?
      return visible_to_cs? && onboarding_agent == user if user.onboarding_agent?

    when 'saved by org'
      if user.agency_user? && visible_to_cs?
        return Job.includes(:picked_by).references(:picked_by).
            where("users.id in (?) and jobs.id = ?", user.my_agency_users.pluck(:id), id).count > 0
      else
        return false
      end

    when 'saved by team'
      if user.agency_user? && visible_to_cs?
        return Job.includes(:picked_by).references(:picked_by).
            where("users.id in (?) and jobs.id = ?", user.my_team_users.pluck(:id), id).count > 0
      else
        false
      end

    when 'saved'
      user.agency_user? ? (picked_by.find(user.id) && visible_to_cs?) : false
    when 'assigned hiring organizations'
      return hiring_organization_id.eql?(user.hiring_organization_id)
    else
      false
    end
  end

  def if_visible_to(user)
    return false unless user.all_permissions['jobs']
    case user.all_permissions['jobs']
    when 'all'
      visible_to_cs?
    when 'assigned clients'
      return visible_to_cs && is_supervisor?(user) if user.supervisor?
      return visible_to_cs && is_account_manager?(user) if user.account_manager?
      return visible_to_cs && is_onboarding_agent?(user) if user.onboarding_agent?
    when 'assigned jobs'
      return visible_to_cs && supervisor == user if user.supervisor?
      return visible_to_cs && account_manager == user if user.account_manager?
      return visible_to_cs && onboarding_agent == user if user.onboarding_agent?
    when 'published'
      if visible_to_cs && user.agency_user?
        return false unless user.restrict_access || user.tnc

        if visible_to_cs && user.restrict_access
          return publishable? && Job.get_list_by_access(user).where(id: id).exists?
        else
          return visible_to_cs &&
                 publishable? &&
                 Job.invited_distributes_jobs(user).where(id: id).exists?
        end
      else
        visible_to_cs && publishable? && !is_private
      end
    else
      false
    end
  end

  def beeline_stage
    return unless beeline?
    job_providers.order('created_at desc').first.data['status']
  end

  def get_currency_symbol
    case currency
    when "USD", "CAD", "AUD", "NZD"
      "&#036;"
    when "GBP;"
      "&#163;"
    when "INR"
      "&#8377;"
    when "EUR"
      "&#128;"
    else
      "&#036;"
    end
  end

  def standardize_job_address_format
    return "#{city}, #{state}, #{country_obj['name']}" if ["CA", "US"].include?(country)

    "#{city}, #{country_obj['name']}"
  end

  def sendgrid_default_categories
    [job_id, category.try(:name)]
  end

  def sendgrid_categories_for(value)
    {
      submitted: ['Candidate Submitted'],
      applied: ['Candidate Applied'],
      new_job_invite: ['New Job Opportunity'],
      resend_invite: ['Resend Invite'],
      withdrawn: ['Candidate Withdrawn'],
      disqualified: ['Candidate Disqualified'],
      reinitiated: ['Candidate Reinitiated'],
      offer_rejected: ['Offer Letter Rejected'],
      offer_accepted: ['Offer Letter Accepted'],
      offer: ['Offer Letter Prepared'],
      offer_resend: ['Offer Letter Resend'],
      onboarding: ['Onboarding Package Prepared'],
      doc_rejected: ['Document Rejected'],
      rtr_signed: ['RTR Signed'],
      assignment_extention: ['Assignment Extension'],
      closed: ['Job Closed'],
      reopened: ['Job Reopened'],
      premium: ['Premium Access Granted'],
      hold: ['Job On-hold'],
      resume: ['Job Resumed'],
      published: ['New Job Listing'],
      assigned: ['Assigned to Job'],
      new_job_opportunity: ['New Job Opportunity Recommendations'],
      job_opportunity_saved: ['Job Opportunity Saved'],
      job_opportunity_dismissed: ['Job Opportunity Dismissed'],
      updated: ['Job Opportunity Updated'],
      bill_rate_updated: ['RTR Bill Rate Updated'],
      job_under_review: ['Job Under Review'],
    }[value] + sendgrid_default_categories
  end

  def viewed_recommend(recruiter)
    view = views.where(user: recruiter).last
    views.create(user: recruiter) unless view
    dist = recruiter.distributions.active.where(job_id: id).last
    return unless dist
    dist.update_column(:viewed_count, ((dist.viewed_count || 0) + 1))
  end

  def assign_distributors(params, creator: nil)
    return if params[:recruiters].empty?
    creator = creator ||= User.crowdstaffing
    notifiable = []
    recruiter_ids = params[:recruiters].collect { |recruiter| recruiter[:id] }

    users = User.left_joins(:agency).
      where(id: recruiter_ids, agencies: { restrict_access: false }).
      distinct

    users.each do |user|
      next if affiliates.where(user_id: user.id).exists?
      distributions.find_or_create_by(
        user_id: user.id,
        status: :active,
        created_by: creator
      )
      notifiable << user.id
    end

    system_notification(notifiable)
    ExpireRecommendationJob.set(wait_until: 2.weeks.from_now).perform_later(self)
  end

  def system_notification(notifiable)
    return if notifiable.empty?
    SystemNotifications.perform_later(
      self,
      'job_opportunity',
      (published_by || created_by),
      notifications.where(key: 'job_published').last&.user_agent,
      notifiable
    )
  end

  def total_disqualified_count
    talents_jobs.where(rejected: true).count
  end

  def is_recommended?(user)
    distributions.visible_to(user).exists?
  end

  def can_be_restricted?
    !(stage.eql?('Disabled') || is_closed?) && published_at
  end

  def all_new_recruiters
    recruiters_jobs.saved.order('created_at desc')
  end

  def new_recruiters
    all_new_recruiters.limit(10).map(&:user).
      as_json(only: [:id, :email, :cs_email, :avatar, :image_resized, :first_name, :last_name])
  end

  def active_recruiters_count
    picked_by.verified.count
  end

  def accessible_at(accessible)
    published_at > accessible.updated_at ? published_at : accessible.updated_at
  end

  def full_time?
    type_of_job.eql?('Full Time')
  end

  def contract?
    type_of_job.eql?('Contract')
  end

  def published?
    persisted? && published_at.present? && ['Draft', 'Scheduled'].exclude?(stage)
  end

  def publishable?
    published_at.present? && published_at < Time.now
  end

  def delete_acknowledged_data
    acknowledge_job_hold_users.delete_all
  end

  def add_exclusive_access_end_time
    return unless billing_term&.is_exclusive
    case billing_term.exclusive_access_period
    when 'hours'
      time = published_at + billing_term.exclusive_access_time.hours
    when 'days'
      time = published_at + billing_term.exclusive_access_time.days
    end
    update_column(:exclusive_access_end_time, time)
    AutoDismissalExclusiveJob.set(wait_until: exclusive_access_end_time).perform_later(id)
  end

  def notifiers
    [
      hiring_watcher_ids,
      account_manager_id,
      onboarding_agent_id,
      supervisor_id,
      hiring_manager_id,
    ].flatten.compact
  end

  def notifiable_users
    users_ids = [
      picked_by_ids,
      hiring_watcher_ids,
      account_manager_id,
      hiring_manager_id,
    ].flatten.compact.uniq

    User.verified.where(id: users_ids)
  end

  def internal_notifiers
    [account_manager_id, onboarding_agent_id, supervisor_id].flatten.compact
  end

  def enterprise_users
    users_ids = [hiring_manager_id, hiring_watcher_ids].flatten.compact.uniq

    User.verified.where(id: users_ids)
  end

  def all_ho_users(user)
    users_ids = [hiring_manager_id, hiring_watcher_ids]

    users_ids += [hiring_organization&.owner]
    users_ids += hiring_organization&.users&.where(primary_role: 'enterprise admin').pluck(:id)
    users_ids += [user.id] if user.hiring_organization_id.eql?(hiring_organization_id)

    User.verified.where(id: users_ids.flatten.compact.uniq)
  end

  def get_billing_term
    return if hiring_organization.blank?
    BillingTerm.
      left_outer_joins(:categories).
      where(
        type_of_job: type_of_job,
        hiring_organization_id: hiring_organization_id,
        categories: { id: category_id }
      ).
      distinct.
      last
  end

  def is_acknowledged_on_hold(user)
    acknowledge_job_hold_users.where(user_id: user.id).exists?
  end

  def notify_internal_to_review
    return unless visible_to_cs?
    emails = client.shared_users.
      where(primary_role: ['account manager', 'supervisor']).
      pluck(:email).
      uniq

    if emails.any?
      JobsMailer.notify_am_to_review(self, emails).deliver_now
    end
  end

  def under_review?
    stage.eql?('Under Review')
  end

  def applicants(login_user)
    shareables.shared_talents.visible_to(login_user).pluck(:talent_id).uniq.count
  end

  def unique_links(login_user)
    share_links.visible_to(login_user).count
  end

  def unique_views(login_user)
    shareables.visible_to(login_user).sum(:visits)
  end

  def unique_clicks(login_user)
    share_links.visible_to(login_user).sum(:clicks)
  end

  def compute_job_completeness
    job_score = 0
    Job::JOB_SCORE_VALUES.each do |field, value|
      next if self.send(field).blank?
      if value.is_a?(Integer)
        job_score += value if self.send(field).present?
      else
        case value[:type]
        when 'array'
          job_score += self.send(field).size >= value[:max] ? value[:max] : self.send(field).size
        when 'json'
          job_score += self.send(field).values.compact.collect { |field_value|
            field_value.to_f.zero? ? 0 : value[:score]
          }.sum
        when 'text'
          text_size = Nokogiri::HTML(self.send(field)).xpath("//text()").to_s.size
          job_score += [text_size / value[:char_per_point], value[:max]].min
          job_score += 5 if field.to_s == 'summary' && text_size >= 1000
        end
      end
    end

    job_score
  end

  def structured_hash(hash_obj)
    return {} if hash_obj.blank?
    structured_hash = {}
    hash_obj.each do |key, value|
      structured_hash[key[0]] ||= {}
      structured_hash[key[0]][key[1]] = value if key[1].present?
    end
    structured_hash
  end

  def leaderboard_statistics
    stage_stats = structured_hash(MetricsStage.
      where(job_id: id, stage: ['Submitted', 'Applied', 'Hired']).
      joins(:user).where("users.role_group = 2").
      group(:stage, :user_id).count)

    recruiters_submitted_time = MetricsStage.
      where(job_id: id, stage: 'Submitted').
      joins(:user).where("users.role_group = 2").
      group(:user_id).minimum(:created_at)

    interview_stats = MetricsStage.
      where(job_id: id).where("sort_order > 2 AND sort_order < 3").
      joins(:user).where("users.role_group = 2").select(:talents_job_id).
      distinct.group(:user_id).count

    stats = {
      first_submitted: get_recruiter_data(reduce_hash(recruiters_submitted_time).min),
      most_submissions: get_recruiter_data(reduce_hash(stage_stats['Submitted']).max),
      most_applied: get_recruiter_data(reduce_hash(stage_stats['Applied']).max),
      hired: structure_recruiter_data(stage_stats['Hired']),
      most_interview: get_recruiter_data(reduce_hash(interview_stats).max),
    }
    if stats[:first_submitted].present?
      stats[:first_submitted][:value] = (stats[:first_submitted][:value].to_i -
        published_at.to_i) / 3600.to_f
    end
    stats
  end

  def job_related_objs
    { job: { id: id, title: title, job_id: job_id }}.merge!(client.client_related_objs)
  end

  def hard_delete_job
    return if talents_jobs.any?
    affiliates.delete_all
    recruitment_pipeline.pipeline_steps.delete_all
    recruitment_pipeline.delete
    if onboarding_package
      onboarding_package.onboarding_documents.delete_all
      onboarding_package.delete
    end
    csmm_scores.delete_all
    notes.delete_all
    media.delete_all
    # potential_earnings.delete_all
    acknowledge_job_hold_users.delete_all
    accessible_jobs.delete_all
    exclusive_jobs.delete_all
    agencies_jobs.delete_all
    invitations.delete_all
    ho_jobs_watchers.delete_all
    hiring_watchers.delete_all
    badges.delete_all
    badged_users.delete_all
    change_histories.delete_all
    share_links.delete_all
    shareables.delete_all
    shared_talents.delete_all
    questionnaire.questions.delete_all
    questionnaire.delete
    ActiveRecord::Base.connection.execute("
      delete from sd.recruiter_feedback where recommendation_id in (
        select id from  sd.jobs_recruiters_recommendation where job_id = '#{id}'
      )")
    ActiveRecord::Base.connection.execute("delete from sd.jobs_recruiters_recommendation where job_id = '#{id}'")
    really_destroy!
  end

  def bill_rate_negotiatiable?
    contract? && !bill_rate[:markup] && (stage.eql?('Open') || stage.eql?('On Hold'))
  end

  def is_available_to_marketplace?
    !is_private && (
      exclusive_access_end_time.blank? || exclusive_access_end_time < Time.now
    )
  end

  private

  def destroyable
    !enable
  end
end
