require 'csmm/match_maker'
module ModelCallback
  module CallbacksNote
    def self.included(receiver)
      receiver.class_eval do
        before_save :init_visibility
        after_save :send_email
        after_create :calculate_announcement_average

        after_create :handle_generic_action_metrics
        after_commit :update_read_notes_user, on: [:create, :update]
      end
    end

    ########################
    private
    ########################

    def send_email
      return unless ['TalentsJob', 'Job'].include?(notable_type)

      if mentioned_ids.any?
        if announcement?
          Message::NoteMessageService.send_email(mentioned, self)
        else
          mentioned.each { |notify| NoteMailer.send_email(self, notify).deliver_now }
        end
      end

      return if announcement?

      if persisted? && user.hiring_org_user? && notable_type.eql?('TalentsJob')
        case visibility
        when 'HO_AND_CROWDSTAFFING'
          NoteMailer.comment_notification(id, notable.job.account_manager_id).deliver_later
        when 'HO_AND_CROWDSTAFFING_AND_TS'
          notable.
            crowdstaffing_ts_users.
            each { |notify| NoteMailer.comment_notification(id, notify.id).deliver_later }
        end
      elsif persisted? && user.internal_user? && notable_type.eql?('TalentsJob')
        case visibility
        when 'CROWDSTAFFING_AND_TS'
          NoteMailer.comment_notification(id, notable.user_id).deliver_later
        when 'HO_AND_CROWDSTAFFING'
          notable.
            ho_users.
            each { |notify| NoteMailer.comment_notification(id, notify.id).deliver_later }
        when 'HO_AND_CROWDSTAFFING_AND_TS'
          notable.
            ho_ts_users.
            each { |notify| NoteMailer.comment_notification(id, notify.id).deliver_later }
        end
      elsif persisted? && user.agency_user? && notable_type.eql?('TalentsJob')
        case visibility
        when 'CROWDSTAFFING_AND_TS'
          NoteMailer.comment_notification(id, notable.job.account_manager_id).deliver_later
        when 'HO_AND_CROWDSTAFFING_AND_TS'
          notable.
            ho_crowdstaffing_users.
            each { |notify| NoteMailer.comment_notification(id, notify.id).deliver_later }
        end
      end
    end

    def init_visibility
      return unless user
      return if user.hiring_org_user?
      (self.visibility = user.internal_user? ? 'CROWDSTAFFING' : 'TS') if visibility.blank?
      self.visibility = parent.visibility if parent.present?
      self
    end

    def calculate_announcement_average
      return unless announcement
      CSMM::MatchMaker.current.calculate_feedback(
        notable_id,
        Time.zone.now.to_s,
        CSMM::MatchMaker::MEAN_TIME_FEEDBACKS
      )
    end

    def handle_generic_action_metrics
      return unless notable_type == 'Job' || notable_type == 'TalentsJob'
      obj_values = {
        job_id: notable_type == 'Job' ? notable_id : notable.job.id,
        time: Time.zone.now.to_s,
        action_model: self.class.to_s,
        changes: [],
        _version: 2
      }

      CsmmTaskHandlerJob.set(wait: 5.seconds).
        perform_later('calculate_job_generic_action_metrics', obj_values)
    end

    def update_read_notes_user
      ImportReadNotesUserJob.set(wait: 2.seconds).perform_later(id)
    end
  end
end
