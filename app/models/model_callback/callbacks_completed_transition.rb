module ModelCallback
  module CallbacksCompletedTransition

    def self.included(receiver)
      receiver.class_eval do
        after_create :update_old_completed_transitions
        before_validation :init_tag
        after_create :resend_invitation
      end
    end

    def init_tag
      self.email = talents_job.email
      return if stage.eql?('Offer')
      return unless job
      self.pipeline_step = RecruitmentPipeline.where(embeddable: job).
        first.pipeline_steps.where(stage_label: stage).first

      return if self.tag
      case self.stage
        when 'Sourced'
          self.tag = 'sourced'
        when 'Invited', 'On-boarding'
          self.tag = 'sent' #opened
        else
          if pipeline_step.eventable && event
            self.tag = event.end_date_time.nil? ? 'awaiting confirmation' : 'scheduled'
          else
            self.tag = stage.downcase
          end
      end
    end

    ########################
    private
    ########################

    def update_old_completed_transitions
      talents_job.completed_transitions.where(stage: stage, current: true)
        .where.not(id: id).update_all(current: false)
    end

    def resend_invitation
      return unless stage == "Invited"
      return if talents_job.all_rtr.count == 1
      old_invite = talents_job.completed_transitions.where(stage: stage).where.not(id: id)
      return if old_invite.count.zero? && talents_job.pending_rtr.blank?
      assoc_user = LoggedinUser.current_user.presence || updated_by
      talents_job.send_notification_for_talentsjob(["Stage"], assoc_user, LoggedinUser.user_agent)
    end
  end
end
