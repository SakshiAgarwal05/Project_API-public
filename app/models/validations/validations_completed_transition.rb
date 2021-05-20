module Validations
  module ValidationsCompletedTransition

    def self.included(receiver)
      receiver.class_eval do
        validates :stage, :tag, presence: true
        validates :note, presence: { unless: proc { |x| %w(Invited Signed).include?(x.stage) } }
        # validates :stage, uniqueness: {scope: :talents_job}, unless: Proc.new{|x| ["Invited", "Offer"].include?(x.stage)}
        validate :check_rtr_attached
        validate :stage_transition, on: :create
        validate :submittable, on: :create
        validate :is_onboarded, on: :create
        validate :reinvite, on: :create
        validate :if_valid_talent
        validate :cannot_invite_already_signed_job
        validate :unverified_candidate
        validate :resend_offer, on: :create
        validate :check_talent, on: :create, if: proc { |ct| ct.changed.include?('stage') }
        validate :check_if_already_rejected_offer
        validate :check_if_spoken_to_candidate
      end
    end

    def check_if_spoken_to_candidate
      return if talents_job.interested || changed.exclude?('stage')
      writeup = talents_job.candidate_overview
      if stage.eql?('Invited') || (['Signed', 'Submitted'].include?(stage) && rtr.last&.offline)
        errors.add(:candidate_overview, "can't be blank") if writeup.blank?
        errors.add(:base, "Please make sure you have spoken to candidate.") if spoken_to_candidate.is_false?
      end
    end

    def check_if_already_rejected_offer
      return unless tag_was.eql?('declined') && tag.eql?('declined')
      errors.add(:base, 'You cannot reject an already rejected offer')
    end

    def check_rtr_attached
      return if !new_record? ||
        rtr.any? ||
        talents_job.rtr ||
        stage.eql?("Sourced") ||
        qualified_stage('Offer') ||
        (stage.eql?('Signed') && talents_job.interested)

      errors.add(:base, I18n.t("talents_job.error_messages.blank_rtr"))
    end

    ########################
    private
    ########################

    def unverified_candidate
      skip_verification = talents_job.offline ||
        talents_job.talent.confirmed? ||
        talents_job.stage != 'Applied'

      return if skip_verification

      errors.add(:base, I18n.t("talents_job.error_messages.candidate.unverified"))
    end

    def cannot_invite_already_signed_job
      return unless stage == 'Invited'
      already_invited = TalentsJob.where(job_id: talents_job.job_id,
        talent_id: talents_job.talent_id).where.not(id: talents_job.id)
      return unless already_invited.count.zero?
      signed = already_invited.reached_at("Signed").any?
      rejected = already_invited.reached_at("Invited").withdrawn.any?
      errors.add(:base, "Candidate already signed this job") if signed
      errors.add(:base, "Candidate already rejected this job") if rejected
    end

    def reinvite
      return unless stage.eql?('Invited')
      old_invite = talents_job.
        completed_transitions.
        where(stage: stage, email: talents_job.email).
        where.not(id: id)

      return if old_invite.count.zero? ||
        old_invite.count < 5 ||
        old_invite.where(current: true)[-1].created_at + 72.hours <= Time.now

      errors.add(:base, I18n.t('talents_job.error_messages.re_invite'))
    end

    def valid_sign_offline_obj?
      talents_job.valid_talents_job? &&
      ['Invited', 'Signed'].include?(stage)
    end

    def stage_transition
      if stage!= 'Signed' && stage != talents_job.stage
        raise "Invalid movement"
      end

      return if valid_sign_offline_obj? && rtr&.last&.offline
      if stage.eql?('Signed') && updated_by.is_a?(User)
        self.errors.add(:base, "Can't move candidate from #{talents_job.stage_was} to #{stage}")
        return self
      end
      return if stage.nil? || job.blank? || check_if_next_stage || check_skip
      self.errors.add(:base, "Can't move candidate from #{talents_job.stage_was} to #{stage}")
    end

    def check_if_next_stage
      return true if talents_job.stage_was == 'Invited' && stage == 'Submitted'
      [talents_job.all_stages[talents_job.stage_was], talents_job.stage_was].include?(stage)
    end

    def interested_candidate
      stage.eql?("Signed") && talents_job.interested && stage_was.nil?
    end

    def check_skip
      if job.beeline?
        return true if talents_job.stage_was == 'Applied' && stage == 'Offer'
        return false if qualified_stage('Submitted')
      end
      talents_job.skippable? && skippable_stage? && talents_job.skippable_user?(updated_by)
    end

    # recruiter can not submit a candidate if profile is not added.
    def submittable
      return unless self.stage.eql?('Submitted')
      errors.add(:base, 'Please select a copy of profile for this user') if talents_job.profile.nil?
    end

    def is_onboarded
      return if talents_job.talent.blank?

      onboarded = talents_job.
        talent.
        talents_jobs.hired.where.not(stage: 'Assignment Ends').active.last

      return if onboarded.blank? || onboarded == talents_job

      errors.add(
        :base,
        "This talent have Accepted Letter of Offer for Job: #{onboarded.job.try(:title)} "
      )
    end

    def if_valid_talent
      return if talents_job.interested && talents_job.talent.blank?
      return if talents_job.talent.try(:enable) || talents_job.withdrawn
      errors.add(:base, I18n.t('talent.error_messages.talent_disabled'))
    end

    def resend_offer
      return unless stage.eql?('Offer')
      errors.add(:base, I18n.t('talents_job.error_messages.offer_accepted', job_title: talents_job.job.title)) if talents_job.offer_accepted.present?
    end

    def check_talent
      errors.add(
        :base,
        I18n.t('talents_job.error_messages.talent.do_not_contact', stage: stage, talent: talent.name)
      ) if talent && talent.do_not_contact
    end
  end
end
