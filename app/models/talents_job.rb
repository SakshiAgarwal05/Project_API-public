class TalentsJob < ApplicationRecord
  acts_as_paranoid
  HIDDEN_FIELDS = [
    :invited_talent_id,
    :invitation_expire_at
  ]

  include HiddenFields
  include Elasticsearch::Model
  # include Elasticsearch::Model::Callbacks
  include GlobalID::Identification
  include AddAbility

  include Fields::FieldsTalentsJob
  include Validations::ValidationsTalentsJob
  include ModelCallback::CallbacksTalentsJob
  include Scopes::ScopesTalentsJob
  include Constants::ConstantsTalentsJob
  include ES::ESTalentsJob
  include Notifiable
  include CurrentUser
  include Concerns::ActiveCandidatesListingValues

  def confirm_email
    talent.confirm_email(email)
  end

  def accessable_users
    [
      user.try(:find_admins),
      job.account_manager.try(:find_admins),
      job.supervisor.try(:find_admins)
    ].flatten.uniq
  end

  # other attrs is for talent apply to job by himself/herself.
  class << self
    def es_includes(options = {})
      [
        :assignment_detail,
        :talent,
        :profile,
        job: [:client, :category],
        user: :agency,
      ]
    end

    def statistics_tile(jobs, login_user)
      records = where(job_id: jobs.collect(&:id).uniq).
        not_rejected.
        not_withdrawn.
        joins(
          Arel.sql(
            "left outer join pipeline_notifications on
              pipeline_notifications.talents_job_id = talents_jobs.id
            AND pipeline_notifications.user_id = '#{login_user.id}'
            AND pipeline_notifications.stage = talents_jobs.stage"
          )
        ).
        visible_to(login_user).
        select(
          "COUNT(*) as count, count(distinct(pipeline_notifications.id)) AS unread_count,
          talents_jobs.job_id AS job_id,
          talents_jobs.stage AS stage"
        ).
        group(:job_id, :stage).
        group_by(&:job_id)

      results = {}
      jobs.collect(&:id).uniq.each do |key|
        login_user.statistics_tile_stages.each do |stage|
          count, unread_count = get_count_from_result(records[key] || [], stage)
          results[key] ||= []
          results[key] << { key: stage, count: count, unread_count: unread_count }
        end
      end
      results
    end

    def get_count_from_result(result, stage)
      filtered = if stage.eql?('Interview')
                   result.reject { |r| PipelineStep::FIXED_STAGES.include?(r.stage) }
                 else
                   result.select { |r| r.stage == stage }
                 end

      [filtered.sum(&:count), filtered.sum(&:unread_count)]
    end
  end

  def latest_transition_obj
    completed_transitions.where(stage: stage).order('created_at asc').last
  end

  def stages_list
    return [] if job.nil?
    job.stages_list rescue Job.deleted.find(job_id).stages_list
  end

  # list pipeline steps
  def stages
    transitions = {}
    pipeline_stages = [nil] + stages_list.collect(&:stage_label)
    pipeline_stages[0..-2].each_with_index do |s, i|
      transitions[s] = pipeline_stages[i + 1]
    end
    transitions
  end

  # list all pipeline steps
  def all_stages
    transitions = {}
    pipeline_stages = [nil] + stages_list.collect(&:stage_label)
    pipeline_stages.each_with_index do |s, i|
      transitions[s] = pipeline_stages[i + 1]
    end
    transitions
  end

  # set view to true if candidate views a job
  def view
    update_column(:viewed, true)
  end

  # automatically rejects jobs.
  def auto_withdrawn(options = {})
    self.if_auto_withdrawn = true
    update_attributes(
      rejected: true,
      primary_disqualify_reason:  options[:primary_disqualify_reason] || 'Candidate Not Available',
      secondary_disqualify_reason: options[:secondary_disqualify_reason] || 'Candidate is already represented',
      sentiment: options[:sentiment] || 'Neutral',
      reason_notes: options[:reason],
      withdrawn: true,
      withdrawn_by: LoggedinUser.current_user,
      reason_to_withdrawn: options[:reason],
      withdrawn_notes: options[:reason]
    )
  end

  def qualified_stage(check_stage)
    stage_list = stages.values
    begin
      next_stage_list = stage_list[stage_list.index(check_stage)..-1]
      next_stage_list.include?(stage)
    rescue
      false
    end
  end

  # if talent is submitted to account manager or not.
  def submitted?
    qualified_stage 'Submitted'
  end

  def signed?
    qualified_stage 'Signed'
  end

  # if talent is hired
  def hired?
    qualified_stage 'Hired'
  end

  def offerable?
    self.next_stage == 'Offer'
  end

  def offered?
    return false if !offer_letter
    offer_letter.active?
  end

  def offer_extended?
    return false if !offer_extension
    offer_extension.active? && tag.eql?('offer_extended')
  end

  def offer_extension_on_hold?
    offer_extend.is_false? && tag.eql?('not_extended')
  end

  def assignment_ended?
    completed_transitions.where(stage: "Assignment Ends").any?
  end

  def onboarded?
    qualified_stage "On-boarding"
  end

  def onboarding_complete?
    completed_transitions.where(stage: 'Assignment Begins').count > 0
  end

  def for_bill_rate_negotiation?
    return if user.blank?
    return if withdrawn.is_true?
    return if !(rtr.incumbent_bill_rate > 0)

    if recruiter_incumbent? || (user.internal_user? && job.hiring_manager.present?)
      if hired?
        completed_transitions.where(stage: ['Assignment Begins', 'Assignment Ends']).count > 0
      else
        submitted?
      end
    end
  end

  def applied?
    qualified_stage "Applied"
  end

  def listing_rtr
    return all_rtr if all_rtr.count == 1
    (
      all_rtr.where(
        "(('rtrs.rejected_at' is not NULL) OR
          ('rtrs.signed_at' is not NULL)) AND
        'rtrs.reject_reason' != 'Auto rejected by system as new RTR has been created'"
      ) +
      [all_rtr.order('created_at desc').first]
    ).compact.uniq
  end

  # check if supplied user can change pipeline stage
  def is_editable_by?(u)
    return false if !job.if_my_job(u) ||
      withdrawn ||
      !(active || stage.eql?('Assignment Ends')) ||
      applied_to_beeline?

    list = stages.values
    from_stage = u.my_jobs_permissions['move org candidate from stage']
    to_stage = u.my_jobs_permissions['move org candidate till stage']

    return true if from_stage &&
      to_stage &&
      (
        ((list[list.index(from_stage)..list.index(to_stage)] rescue []).include?('Assignment Ends') && stage.eql?('Assignment Ends')) ||
        (list[list.index(from_stage)..list.index(to_stage)] rescue []).include?(next_stage)
      )

    return false if user != u

    return true if u.my_jobs_permissions['send letter of offer'] && offerable?

    from_stage = u.my_jobs_permissions['move own candidate from stage']
    to_stage = u.my_jobs_permissions['move own candidate till stage']

    return true if from_stage &&
      to_stage &&
      (list[list.index(from_stage)..list.index(to_stage)] rescue []).include?(next_stage)

    false
  end

  def is_editable_profile?(u)
    return true if active && Job.my_jobs(u).find(job_id) && u.my_jobs_permissions['update candidate details']
  end

  def applied_to_beeline?
    job.beeline? && qualified_stage('Applied')
  end

  # check if supplied user can reject candidate
  def is_rejectable_by?(u)
    return false if !active || !Job.my_jobs(u).find(job_id) || onboarding_complete? || rejected
    return true if u.my_jobs_permissions['reject org candidate']
    return true if user == u && u.my_jobs_permissions['reject own candidate']
    false
  end

  # check if supplied user can reject candidate
  def is_reinstatable_by?(u)
    return false if !active || !Job.my_jobs(u).find(job_id) || onboarding_complete? || !rejected
    return false if applied_to_beeline?
    return true if u.my_jobs_permissions['reject org candidate']
    return true if user == u && u.my_jobs_permissions['reject own candidate']
    false
  end

  # check if supplied user can withdraw candidate
  def is_withdrawable_by?(u)
    return false if !active || !Job.my_jobs(u).find(job_id) || onboarding_complete? || !rejected
    return true if u.my_jobs_permissions['withdraw org candidate']
    return true if user == u && u.my_jobs_permissions['withdraw own candidate']
    false
  end

  def skippable?
    submitted?
  end

  def skippable_user?(u)
    return false if u.nil? || !u.is_a?(User)
    u.my_jobs_permissions['hop a candidate']
  end

  def event_expired(event)
    return if event.end_date_time >= Time.now
    ct = completed_transitions.where(event_id: event.id).first
    return if ct.nil?
    ct.update_column(:tag, "under review")
  end

  def event_in_progress(event)
    return if event.start_date_time > Time.now.utc || event.end_date_time < Time.now.utc
    ct = completed_transitions.where(event_id: event.id).first
    return if ct.nil?
    ct.update_column(:tag, "in-progress")
  end

  def all_active_rtr
    all_rtr.where(rejected_at: nil)
  end

  def rtr
    all_active_rtr.last
  end

  def all_pending_rtr
    all_rtr.pending
  end

  def pending_rtr
    all_pending_rtr.last
  end

  def rtr_signed
    completed_transitions.where(stage: "Signed").first
  end

  def recent_signed_rtr
    all_active_rtr.where.not(signed_at: nil).last
  end

  def invited_obj
    completed_transitions.where(stage: "Invited", current: true).last
  end

  def offer_accepted
    completed_transitions.where(stage: "Hired", current: true).last
  end

  def offer_rejected
    completed_transitions.where(stage: "Offer", tag: 'declined', current: true).last
  end

  def offer_letter
    all_offer.last
  end

  def offer_extension
    all_offer_extensions.order("created_at").last
  end

  def is_offer_rejected
    offer_rejected.present?
  end

  def offer_sent
    completed_transitions.where(stage: "Offer", current: true).last
  end

  def recruiter_incumbent?
    user&.agency&.invited_for(job)&.incumbent?
  end

  def onboarding_sent
    completed_transitions.where(stage: "On-boarding", current: true).last
  end

  def read_invitation(rtr_id)
    return if interested
    invited_obj.update_attributes(tag: 'opened')
    rtr = all_rtr.find(rtr_id)
    rtr.update_attributes(tag: 'opened') if rtr
  end

  def view_invitation(rtr)
    return if interested
    return unless invited_obj
    invited_obj.update_attributes(tag: 'viewed')
    rtr = all_rtr.find(rtr.id)
    return unless rtr
    rtr.update_attributes(tag: 'viewed')
    TalentMailer.account_verify_notify(talent).deliver_now if !talent.confirmed?
  end

  def read_offer
    offer_sent.update_attributes(tag: 'opened') if !offer_sent.tag.eql?('not_extended')
  end

  def viewed_offer
    offer_sent.update_attributes(tag: 'viewed') if !offer_sent.tag.eql?('declined') ||
      !stage.eql?('Hired')
  end

  def read_onboarding
    onboarding_sent.update_attributes(tag: 'in-progress')
  end

  def mark_read(user)
    notifications = pipeline_notifications.visible_to(user)
    notifications.delete_all if notifications.any?
  end

  def prev_stage
    stage_list = stages.values
    prev_stage = stage_list[0...stage_list.index(stage)].last
  end

  def reinstated
    rejected.is_false? && reinstate_by.present?
  end

  def valid_talents_job?
    return false unless job
    job.not_closed && rejected.is_false? && withdrawn.is_false?
  end

  def revised_rtr
    signed?
  end

  def valid_sign_offline_obj?
    valid_talents_job? && ['Sourced', 'Invited'].include?(stage)
  end

  def overtime?
    assignment_detail&.overtime
  end

  def tag
    return 'Withdrawn' if withdrawn?
    return 'Disqualified' if rejected?
    latest_transition_obj.tag
  end

  def unread(login_user)
    pipeline_notifications.unread(login_user, stage).exists?
  end

  def locked_access?(login_user)
    return false if PipelineStep::GROUPED_STAGES[:Submitted].exclude?(stage)
    return false if PipelineStep::GROUPED_STAGES[:Submitted].include?(stage) &&
      login_user.hiring_organization.represented_by?(user_id)
    true
  end

  def set_pipeline_notification(login_user)
    PipelineNotifyJob.perform_now(self, login_user)
  end

  def crowdstaffing_ts_users
    User.
      verified.
      where(id: [user_id, job.account_manager_id, job.supervisor_id].compact)
  end

  def ho_ts_users
    User.
      verified.
      where(id: [job.hiring_manager_id, user_id, job.hiring_watcher_ids].flatten.compact)
  end

  def ho_crowdstaffing_users
    User.verified.where(id: job.notifiers)
  end

  def ho_users
    User.
      verified.
      where(id: [job.hiring_manager_id, job.hiring_watcher_ids].flatten.compact)
  end

  def confirmed_pay_rate
    if completed_transitions.where(stage: 'Assignment Begins').count > 0
      assignment_detail
    elsif completed_transitions.where(stage: 'Hired').count > 0
      offer_letter
    elsif all_rtr.count > 1
      all_rtr.where.not(signed_at: nil).last
    end
  end

  def unread_note(user)
    notes.unread(user).visible_to(user)
  end

  def talents_job_related_objs
    { talents_job: { id: id, stage: stage }}
    .merge!(job.job_related_objs)
    .merge!(profile.profile_related_objs)
    .merge!(talent.talent_related_objs)
    .merge!(user.user_related_objs)
  end

  def shareable_source
    return if shared_id.blank?
    talent.shareables.find(shared_id)&.referrer
  end

  def questionnaire_presence?
    recent_signed_rtr.present? &&
    recent_signed_rtr.questionnaire_answers.exists?
  end

  def applied_or_ho_candidate?
    applied? || user.hiring_org_user?
  end
end
