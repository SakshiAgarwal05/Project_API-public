  require "net/http"
require 'csmm/match_maker'

module ModelCallback
  module CallbacksTalentsJob
    def self.included(receiver)
      receiver.class_eval do
        before_validation :init_fields
        after_save  :stage_movement_callbacks,
                    :update_job,
                    :background_jobs,
                    :update_talent

        after_commit on: [:create, :update] do
          ReindexObjectJob.set(wait: 5.seconds).perform_later(self)
        end

        after_commit on: [:destroy] do
          __elasticsearch__.delete_document
        end
      end
    end

    ########################

    private

    ########################

    def init_fields
      if user_id.nil? || talent_id.nil? || job_id.nil?
        return false
      end

      self.active = !(changes_to_save[:withdrawn] == [false, true] || stage == "Assignment Ends" || job.closed?)
      self.agency_id = user.agency_id if user
      if (['stage', 'withdrawn', 'active'] & changes_to_save.keys).any? ||
        ['Invited', 'Offer'].include?(stage)

        reset_invitation_token
      end

      if changes_to_save.keys.include?('rejected')
        self.rejected_at = rejected ? Time.now : nil
      end

      if changes_to_save.keys.include?('withdrawn')
        self.withdrawn_at = withdrawn ? Time.now : nil
      end

      if stage == 'Signed' && will_save_change_to_attribute?(:stage)
        self.stage = 'Submitted'
        if completed_transitions.select { |ct| ct.stage == 'Submitted' }.blank?
          completed_transitions.new(stage: 'Submitted', updated_by: talent, note: 'Auto Submitted.')
        end
      end

      self.next_stage = stages[stage]
      SaveCandidateService.add(user, talent) if talent.get_profile_for(user).nil?
      if new_record?
        create_profile_copy
        init_new_record
      end
    end

    # When a talent/candidate is sourced a new talents_job is created.
    # This method will assign first step automatically.
    def init_new_record
      self.stage = 'Sourced'
      self.email ||= profile.email
      assign_attributes(
        client_id: job.client_id,
        published_at: job.published_at,
        billing_term_id: job.billing_term_id,
        hiring_organization_id: job.hiring_organization_id,
      )

      unless completed_transitions.any?
        completed_transitions.build(stage: stage, updated_by: user, note: 'Candidate saved')
      end
    end

    def create_profile_copy
      # TODO check if it creates resumes too.
      profile = get_master_profile
      assoc_profile = profile.copy_profile
      assoc_profile.profilable = user
      assoc_profile.talent = talent
      self.profile = assoc_profile
    end

    def stage_movement_callbacks
      if (saved_changes.keys & ['withdrawn', 'rejected', 'stage']).any?
        if saved_change_to_stage?
          movement_stage_changed
        elsif saved_change_to_withdrawn? || saved_change_to_rejected?
          movement_done
        end
      end
    end

    def movement_stage_changed
      case stage
      when 'Sourced'
        candidate_sourced(user, LoggedinUser.user_agent)
        set_pipeline_notification(user)
      when 'Applied'
        Message::TalentsJobMessageService.talent_submitted(self) if self.talent.verified

        self.job.enterprise_users.each do |notify_to|
          TalentsJobMailer.notify_ho_candidate_applied(self, notify_to).deliver_now
        end
      when 'Submitted'
        AutoWithdrawCandidateJob.set(wait: 3.seconds).perform_later(id)
        TalentsJobMailer.notify_am_candidate_submitted(self).deliver_now
      when 'Hired', 'On-boarding'
        create_assignment_detail unless assignment_detail
      end
      ct = latest_transition_obj
      if (!ct || ct.stage != stage)
        completed_transitions.build(
          stage: stage,
          updated_by_id: updated_by_id,
          updated_by_type: updated_by_type,
          note: "Moved to next stage by system"
        )
      end
      metrics_stages.each { |ms| ms.update_attribute(:recruiter_id, user_id) } if saved_change_to_user_id?
      MetricsStage.stage_added(self)
    end

    def movement_done
      MetricsStage.stage_added(self)
    end

    def update_job
      UpdateJobOnPipelineMovementJob.set(wait: 3.seconds).perform_later(job_id)
    end

    def background_jobs
      handle_generic_action_metrics
      if saved_change_to_user_id? && user.agency_user?
        CsmmTaskHandlerJob.set(wait: 10.seconds).
          perform_later('handle_recruiter_save', { recruiter_id: user.id, _version: 2 })
      end
      notify
    end

    def handle_generic_action_metrics
      return if Rails.env.development? || Rails.env.test?
      obj_values = {
        job_id: job_id,
        time: Time.zone.now.to_s,
        action_model: self.class.to_s,
        changes: changes.keys,
        _version: 2
      }
      CsmmTaskHandlerJob.set(wait: 5.seconds).
        perform_later('calculate_job_generic_action_metrics', obj_values)
    end

    def create_assignment_detail
      fields = AssignmentDetail::DEFAULT_ATTRIBUTES

      rtr_attributes = rtr ? rtr.attributes.compact : {}
      offer_attributes = offer_letter ? offer_letter.attributes.compact : {}

      assignment_attributes = rtr_attributes.merge!(offer_attributes).
        with_indifferent_access.select { |key, value| fields.include?(key.to_s) }

      assignment_attributes.merge!(
        possibility_of_extension: false,
        updated_by_id: updated_by_id,
        overtime: false,
        talents_job_id: id,
      )

      assignment_attributes[:salary] ||= job.suggested_pay_rate['min']
      assignment_attributes[:location] ||= job.address

      ad = AssignmentDetail.new(assignment_attributes)
      ad.save(validate: false)
    end

    def update_talent
      filtered_changes = saved_changes.select { |key, value| ['withdrawn', 'stage'].include?(key) }
      return if filtered_changes.blank?
      UpdateTalentOnPipelineMovementJob.set(wait: 3.seconds).perform_later(id, filtered_changes)
    end

    def notify
      service = TalentsJobs::NotifyService.new(talents_job: self, changed: changed)
      service.notify
    end

    def get_master_profile
      if interested
        talent.talent_profile_copy || talent
      else
        talent.get_profile_for(user)
      end
    end

    def reset_invitation_token
      pipeline_step = RecruitmentPipeline.
        where(embeddable_id: job.id).first.
        pipeline_steps.where(stage_label: stage).first

      if invitation_token &&
        (
          changes_to_save[:withdrawn] ||
          (changes_to_save[:active] && !active) ||
          (changes_to_save[:stage] &&
            [
              'Signed',
              'Submitted',
              'Applied',
              'Hired',
              'Assignment Begins',
              'Assignment Ends',
            ].include?(stage) && active
          )
        )

        self.invitation_token = nil
      elsif !invitation_token &&
        (
          (['Invited', 'Offer'].include?(stage) && active) ||
          pipeline_step.eventable && event_id
        )
        self.invitation_token ||= Devise.friendly_token
      end
    end

    ##### Depricated #######

    # def create_talents_jobs_resume
    #   return if profile.nil?
    #   return unless talent &&
    #     profile&.resumes.count.zero? &&
    #     get_master_profile

    #   get_master_profile.resumes.order('master_resume desc').each do |resume|
    #     begin
    #       if open(resume.resume_path)
    #         duplicate_resume = resume.dup
    #         duplicate_resume.uploadable = profile
    #         duplicate_resume.if_primary = resume.master_resume
    #         duplicate_resume.save
    #       end
    #     rescue
    #       nil
    #     end
    #   end
    # end
  end
end
