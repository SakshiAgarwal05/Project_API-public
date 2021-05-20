module Notifiable
  module NotifiableEvent
    def send_notification_for_event(changed_fields, user, user_agent, changes=nil)
    end

    def event_confirmed(login_user, user_agent, obj)
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: nil,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        created_at: Time.now,
        updated_at: Time.now,
        key: 'event_confirmed',
        label: 'Event Confirmed',
        message: "The event <span class=\"event-btn text-blue\">#{title}</span> has been scheduled. <span class=\"view-event-btn text-blue\">View Event</span>",
      }
      Notification.create(options)
    end

    def event_updated(login_user, user_agent, notification_changes)
      key = 'event_updated'
      label = 'Event Updated'

      message =
        if notification_changes[:required_changes].is_true?
          "#{login_user.name.titleize} has updated the <span class=\"event-btn text-blue\">#{title}</span> event. Are you still going? <span class=\"view-event-btn text-blue\">View Event</span>"
        else
          "#{login_user.name.titleize} has updated the <span class=\"event-btn text-blue\">#{title}</span> event. <span class=\"view-event-btn text-blue\">View Event</span>"
        end

      my_message =
        if notification_changes[:required_changes].is_true?
          "You have updated the <span class=\"event-btn text-blue\">#{title}</span> event. Are you still going? <span class=\"view-event-btn text-blue\">View Event</span>"
        else
          "You have updated the <span class=\"event-btn text-blue\">#{title}</span> event. <span class=\"view-event-btn text-blue\">View Event</span>"
        end

      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: nil,
        read: true,
        viewed_or_emailed: true,
        visibility: login_user.id,
        created_at: Time.now,
        updated_at: Time.now,
        key: key,
        label: label,
        message: my_message,
      }
      Notification.create(options)

      users = event_attendees.user_attendees.where.not(user_id: login_user.id)
      if notification_changes[:new_attendees].any?
        users = users.where.not(email: notification_changes[:new_attendees])
      end

      users.uniq.each do |user|
        options = {
          show_on_timeline: true,
          user_agent: user_agent,
          object: self,
          receiver: self,
          from: nil,
          read: true,
          viewed_or_emailed: true,
          visibility: user.user_id,
          created_at: Time.now,
          updated_at: Time.now,
          key: key,
          label: label,
          message: message,
        }
        Notification.create(options)
      end

      event_attendees.user_attendees.each do |user|
        options = {
          show_on_timeline: true,
          user_agent: user_agent,
          object: self,
          receiver: self,
          from: nil,
          read: true,
          viewed_or_emailed: true,
          visibility: nil,
          non_visibility: user.user_id,
          created_at: Time.now,
          updated_at: Time.now,
          key: key,
          label: label,
          message: "#{login_user.name.titleize} has updated the <span class=\"event-btn text-blue\">#{title}</span> event. <span class=\"view-event-btn text-blue\">View Event</span>",
        }
        Notification.create(options)
      end
    end

    def event_declined(login_user, user_agent, obj)
      key = 'event_canceled'
      label = 'Event Cancelled'
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: nil,
        read: true,
        viewed_or_emailed: true,
        visibility: declined_by_id,
        created_at: Time.now,
        updated_at: Time.now,
        key: key,
        label: label,
        message: "You have cancelled the <span class=\"event-btn text-blue\">#{title}</span> event. <span class=\"view-event-btn text-blue\">View Event</span>",
      }
      Notification.create(options)

      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: nil,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        non_visibility: declined_by_id,
        created_at: Time.now,
        updated_at: Time.now,
        key: key,
        label: label,
        message: "#{declined_by.name.titleize} has cancelled the <span class=\"event-btn text-blue\">#{title}</span> event. <span class=\"view-event-btn text-blue\">View Event</span>",
      }
      Notification.create(options)
    end

    def event_deleted(login_user, user_agent, obj)
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: nil,
        read: true,
        viewed_or_emailed: true,
        visibility: login_user.id,
        created_at: Time.now,
        updated_at: Time.now,
        key: 'event_deleted',
        label: 'Event Deleted',
        message: "You have deleted the <span class=\"event-btn text-blue\">#{title}</span> event from your calendar. <span class=\"view-event-btn text-blue\">View Event</span>",
      }
      Notification.create(options)

      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: nil,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        non_visibility: login_user.id,
        created_at: Time.now,
        updated_at: Time.now,
        key: 'event_canceled',
        label: 'Event Cancelled',
        message: "#{login_user.name.titleize} has cancelled the <span class=\"event-btn text-blue\">#{title}</span> event. <span class=\"view-event-btn text-blue\">View Event</span>",
      }
      Notification.create(options)
    end

    def event_created(login_user, user_agent, obj)
      attendees = event_attendees.non_organizer
      attendee_names = attendees.collect { |x| x.name }.join(", ")
      if start_date_time.present? && start_date_time > Time.now.utc
        key = 'event_scheduled'
        label = 'Event Scheduled'
      elsif start_date_time.nil?
        key = 'event_requested'
        label = 'Event Invitation'
      end

      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: nil,
        read: true,
        viewed_or_emailed: true,
        visibility: event_attendees.organizer.last.user_id,
        created_at: Time.now,
        updated_at: Time.now,
        key: key,
        label: label,
        message: "You have scheduled the <span class=\"event-btn text-blue\">#{title}</span> event and invited #{attendee_names}. <span class=\"view-event-btn text-blue\">View Event</span>",
      }
      Notification.create(options)

      attendees.user_attendees.each do |user|
        options = {
          show_on_timeline: true,
          user_agent: user_agent,
          object: self,
          receiver: self,
          from: nil,
          read: true,
          viewed_or_emailed: true,
          visibility: user.user_id,
          created_at: Time.now,
          updated_at: Time.now,
          key: key,
          label: label,
          message: "You have been invited to the <span class=\"event-btn text-blue\">#{title}</span> event organized by #{event_attendees.organizer.last.name.titleize}. <span class=\"view-event-btn text-blue\">View Event</span>",
        }
        Notification.create(options)
      end

      event_attendees.user_attendees.each do |user|
        options = {
          show_on_timeline: true,
          user_agent: user_agent,
          object: self,
          receiver: self,
          from: nil,
          read: true,
          viewed_or_emailed: true,
          visibility: nil,
          non_visibility: user.user_id,
          created_at: Time.now,
          updated_at: Time.now,
          key: key,
          label: label,
          message: "#{event_attendees.organizer.last.name.titleize} has scheduled the <span class=\"event-btn text-blue\">#{title}</span> event and invited #{attendee_names}. <span class=\"view-event-btn text-blue\">View Event</span>",
        }
        Notification.create(options)
      end
    end

    def multi_slot_response(login_user, user_agent, attendee)
      if attendee.status.eql?('No')
        message = "#{attendee.name.titleize} has confirmed they are not available at any of the time slots for the <span class=\"event-btn text-blue\">#{title}</span> organized by #{event_attendees.organizer.last.name.titleize}. <span class=\"view-event-btn text-blue\">View Event</span>"
        key = 'attendee_declined'
        label = 'Event Invitation Declined'
      elsif attendee.status.eql?('Yes')
        message = "#{attendee.name.titleize} has confirmed their availability for one or more time slots for the <span class=\"event-btn text-blue\">#{title}</span> event organized by #{event_attendees.organizer.last.name.titleize}. <span class=\"view-event-btn text-blue\">View Event</span>"
        key = 'attendee_confirmed'
        label = 'Attendee confirmed their availability'
      end

      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: nil,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        non_visibility: attendee.user_id,
        created_at: Time.now,
        updated_at: Time.now,
        key: key,
        label: label,
        message: message,
      }
      Notification.create(options)

      if attendee.user_id
        if attendee.status.eql?('No')
          message = "You have confirmed that you are not available at any of the time slots for the <span class=\"event-btn text-blue\">#{title}</span> event organized by #{event_attendees.organizer.last.name.titleize}. <span class=\"view-event-btn text-blue\">View Event</span>"
          key = 'attendee_declined'
          label = 'Event Invitation Declined'
        elsif attendee.status.eql?('Yes')
          message = "You have confirmed you availability for one or more time slots for the <span class=\"event-btn text-blue\">#{title}</span> event organized by #{event_attendees.organizer.last.name.titleize}. <span class=\"view-event-btn text-blue\">View Event</span>"
          key = 'attendee_confirmed'
          label = 'Attendee confirmed their availability'
        end

        options = {
          show_on_timeline: true,
          user_agent: user_agent,
          object: self,
          receiver: self,
          from: nil,
          read: true,
          viewed_or_emailed: true,
          visibility: attendee.user_id,
          created_at: Time.now,
          updated_at: Time.now,
          key: key,
          label: label,
          message: message,
        }
        Notification.create(options)
      end
    end

    def attendee_responded(login_user, user_agent, attendee)
      attendees = event_attendees.user_attendees

      if attendee.status.eql?('No')
        message = "#{attendee.name.titleize} has declined the <span class=\"event-btn text-blue\">#{title}</span> event invitation from #{event_attendees.organizer.last.name}. <span class=\"view-event-btn text-blue\">View Event</span>"
        key = 'attendee_declined'
        label = 'Event Invitation Declined'
      elsif attendee.status.eql?('Maybe')
        message = "#{attendee.name.titleize} will maybe attend the <span class=\"event-btn text-blue\">#{title}</span> event organized by #{event_attendees.organizer.last.name.titleize}. <span class=\"view-event-btn text-blue\">View Event</span>"
        key = 'attendee_maybe'
        label = 'Attendee will maybe attend the event'
      elsif attendee.status.eql?('Yes')
        message = "#{attendee.name.titleize} will attending the <span class=\"event-btn text-blue\">#{title}</span> event organized by #{event_attendees.organizer.last.name.titleize}. <span class=\"view-event-btn text-blue\">View Event</span>"
        key = 'attendee_confirmed'
        label = 'Attendee will attend the event'
      end

      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: nil,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        non_visibility: attendee.user_id,
        created_at: Time.now,
        updated_at: Time.now,
        key: key,
        label: label,
        message: message,
      }
      Notification.create(options)

      if attendee.user_id
        if attendee.status.eql?('No')
          message = "You have declined the invitation to the <span class=\"event-btn text-blue\">#{title}</span> event organized by #{event_attendees.organizer.last.name.titleize}. <span class=\"view-event-btn text-blue\">View Event</span>"
          key = 'attendee_declined'
          label = 'Event Invitation Declined'
        elsif attendee.status.eql?('Yes')
          message = "You have confirmed that you will be attending the <span class=\"event-btn text-blue\">#{title}</span> event organized by #{event_attendees.organizer.last.name.titleize}. <span class=\"view-event-btn text-blue\">View Event</span>"
          key = 'attendee_confirmed'
          label = 'Attendee will attend the event'
        end

        options = {
          show_on_timeline: true,
          user_agent: user_agent,
          object: self,
          receiver: self,
          from: nil,
          read: true,
          viewed_or_emailed: true,
          visibility: attendee.user_id,
          created_at: Time.now,
          updated_at: Time.now,
          key: key,
          label: label,
          message: message,
        }
        Notification.create(options)
      end
    end
  end
end
