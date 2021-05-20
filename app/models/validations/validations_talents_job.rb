module Validations
  module ValidationsTalentsJob
    def self.included(receiver)
      receiver.class_eval do
        validates :job, :talent, :stage, presence: true

        validate :if_complete_job

        validates :primary_disqualify_reason,
                  :secondary_disqualify_reason,
                  :reason_notes,
                  presence: true,
                  if: proc { |obj| obj.rejected }

        validates :reason_to_withdrawn,
                  :withdrawn_notes,
                  presence: true,
                  if: proc { |obj| obj.withdrawn && withdrawn_by != obj.talent }

        validate :if_job_closed?
        validate :job_must_be_available_in_my_jobs, on: :create

        validate :check_withdrawn_access, if: proc { |tj| tj.changed.include?("withdrawn") && tj.withdrawn }
        # terms_of_service

        validates :tos, acceptance: true

        validates :user,
                  presence: true,
                  unless: proc { |tj| tj.job&.beeline? || tj.interested || (tj.changed.include?("rejected") && (rejected || tj.reinstate_by)) || tj.withdrawn }

        validate :if_valid_talent

        validate :verified_user

        validate :check_if_talent_is_enabled

        validate :check_if_talent_not_dnd

        validate :no_withdraw_without_reject

        validate :check_talent, if: proc { |tj| tj.changed.include?('stage') }

        validate :check_if_profile_is_complete, on: :create

        validate :check_if_duplicate_talents_job

        validate :check_hiring_availability

        validate :check_if_can_be_reopened

        validates :candidate_overview, html_content_length: { maximum: 5000 }

        validates :candidate_overview, presence: true, if: Proc.new { |tj|
          tj.candidate_overview_was.present? && tj.candidate_overview.blank?
        }

        validate :complete_questionnaire, on: :update
        validate :if_event_completed?, on: :update
        validate :if_reason_select, on: :update
      end
    end

    ########################

    private

    ########################

    def if_reason_select
      return unless stage == 'Assignment Ends'
      if assignment_detail.primary_end_reason.blank?
        errors.add(:base, "Assignment End reason can not be blank")
      end

      if assignment_detail.end_date.blank?
        errors.add(:base, "Assignment End date can not be blank")
      end
    end

    def job_must_be_available_in_my_jobs
      if job.nil? || user.nil? || job.if_saved(user)
        return
      end

      errors.add(:job, "is not saved by user")
    end

    def check_if_profile_is_complete
      if talent.nil? || user.nil? || interested
        return
      end

      profile = talent.get_profile_for(user)
      unless profile
        errors.add(:base, "You need to save this candidate first")
        return
      end
    end

    def no_withdraw_without_reject
      return unless changed.include?("withdrawn")
      return if withdrawn_by.is_a?(Talent)

      if !rejected && withdrawn
        errors.add(:base, I18n.t('talents_job.error_messages.not_rejected'))
      end
    end

    def check_if_talent_is_enabled
      if talent.blank? || talent.enable || rejected_changed? || (withdrawn && withdrawn_changed?)
        return
      end

      errors.add(:base, I18n.t('talents_job.error_messages.candidate.disabled'))
    end

    def check_if_talent_not_dnd
      if talent.nil? || rejected_changed? || (withdrawn && withdrawn_changed?)
        return
      end

      return unless talent.status.eql?('Do Not Contact')
      errors.add(:base, I18n.t('talents_job.error_messages.candidate.dnd'))
    end

    def check_talent
      if persisted? && (changed & %w(rejected withdrawn user_id)).any?
        return
      end

      if talent && talent.do_not_contact
        errors.add(
          :base,
          I18n.t('talents_job.error_messages.talent.do_not_contact', stage: stage, talent: talent.name)
        )
      end
    end

    # do not create a new record if job is not properly created
    def if_complete_job
      return if job.nil?
      errors.add(:job, "is not published or is a disabled job.") if !job.complete_valid_job
    end

    def if_job_closed?
      unless changed.include?('id')
        rejected_fields = %w(rejected rejected_by_id rejected_by_type)
        return if (changed & rejected_fields).any?
        withdrawn_fields = %w(withdrawn withdrawn_by_id withdrawn_by_type)
        return if (changed & withdrawn_fields).any?

        if changed.include?('user_id') && persisted?
          return
        end

        return if offered?
      end

      if job&.is_closed? && !hired?
        errors.add(:base, I18n.t('job.error_messages.status', status: "#{job.stage}"))
      end
    end

    def check_withdrawn_access
      return if if_auto_withdrawn
      return if withdrawn_by == talent
      if withdrawn_by.try(:account_manager?) && user != withdrawn_by
        errors.add(:base, I18n.t('talents_job.error_messages.not_authorize_to_withdraw'))
      elsif PipelineStep::FILLED_STAGES.include?(stage) && (withdrawn_by.try(:agency_owner_admin?) || withdrawn_by.try(:team_admin?) || withdrawn_by.try(:team_member?))
        errors.add(:base, I18n.t('talents_job.error_messages.not_withdraw_on_hired_stage'))
      end
    end

    def if_valid_talent
      if (interested && talent.blank?) ||
        talent&.enable ||
        (changed.include?('withdrawn') && withdrawn) ||
        rejected_changed?
        return
      end

      errors.add(:base, 'This talent is disabled!')
    end

    def verified_user
      if user.nil? || user.confirmed?
        return
      end

      errors.add(:base, I18n.t('talents_job.error_messages.user')) if changed.include?('user_id')
    end

    def check_if_duplicate_talents_job
      return unless talent

      if new_record? && talent.talents_jobs.where(job_id: job_id, user_id: user_id).any?
        errors.add(:base, 'candidate is already represented by you')
      elsif talent.talents_jobs.reached_at('Signed').where(job_id: job_id).where.not(id: id).any?
        errors.add(:base, 'This candidate has been previously submitted for this job. Try another job')
      end
    end

    def check_hiring_availability
      return unless job && applied? && changed.include?('stage') &&
        ['Offer', 'Hired', 'On-boarding', 'Assignment Begins', 'Assignment Ends'].include?(stage)

      return if (job.positions - (job.filled_positions || 0)).positive?
      return if job.talents_jobs.reached_at('Offer').not_rejected.pluck(:id).include?(id)

      errors.add(:base, 'The number of hires cannot exceed the number of positions for the job. If you wish to Hire more candidates, please update positions of this job')
    end

    def check_if_can_be_reopened
      return unless talent
      if stage.eql?('Assignment Begins') && stage_was.eql?('Assignment Ends')
        active_talent_jobs = talent.talents_jobs.where.not(id: id).active.not_withdrawn
        if active_talent_jobs.count.zero? || active_talent_jobs.reached_at('Hired').count.zero?
          self.active = true
        else
          errors.add(:base, 'This candidate has accepted offer for some other job.')
        end
      end
    end

    def complete_questionnaire
      return if PipelineStep::GROUPED_STAGES[:Submitted].include?(stage)
      return unless stage_changed?

      return if recent_signed_rtr.blank? ||
                !recent_signed_rtr.questionnaire_status.eql?('PENDING')

      errors.add(:base, 'Before moving candidate, Please complete questionnaire application form')
    end

    # check if previous action's event is completed or not if it has any.
    def if_event_completed?
      return if stage=="Sourced" || stage == "Signed"
      previous_step = latest_transition_obj
      return if previous_step.nil? || previous_step.event.nil? ||
        previous_step.stage == stage || previous_step.event.finished || check_skip
      self.errors.add(:base, "Event is not completed")
    end

    def check_skip
      completed_transitions.select{ |ct| ct.stage == stage }.last.check_skip
    end
  end
end
