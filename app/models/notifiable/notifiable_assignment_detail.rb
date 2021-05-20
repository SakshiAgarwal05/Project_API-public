module Notifiable
  module NotifiableAssignmentDetail
    def send_notification_for_assignment_updation(changes)
      changed_string = ""
      changes.each do |field, values|
        values[0] = 'null' if values[0].nil?
        values[1] = 'null' if values[1].nil?
        changed_string.concat("<b>#{self.class.human_attribute_name("#{field}")}</b> updated from <b>#{values[0]}</b> to <b>#{values[1]}</b>, ")
      end

      options = {
        show_on_timeline: true,
        user_agent: nil,
        object: talents_job,
        receiver: talents_job,
        from: updated_by,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        created_at: Time.now,
        updated_at: Time.now,
        key: 'assignment_updated',
        label: 'Assignment Updated',
        message: "Worker #{talents_job.talent.name}'s assignment has been updated. #{changed_string}",
      }

      Notification.create(options)
    end
  end
end
