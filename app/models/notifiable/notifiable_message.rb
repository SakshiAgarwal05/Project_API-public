module Notifiable
  module NotifiableMessage
    def job_invite_notification(attributes, current_user, user_agent, job_id)
      from = get_sender
      self.edited_by = from
      job = Job.find job_id rescue nil
      recipient = { object: job, from: from }
      receivers.receiver_users.recepients.each do |receiver|
        user = receiver.user
        send_notifications(
          recipient.merge(to: user),
          NotificationEvent.get_event('Recruiter Invited'),
          {
            team_member_name: user.name,
            team_member_id: user.id,
            job_id: job.id,
            job_title: job.title,
            account_manager: current_user.name
          },
          'job_invite',
          'Job Invite',
          user_agent,
          self
        )
      end
    end
  end
end
