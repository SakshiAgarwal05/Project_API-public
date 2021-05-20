module Notifiable
  module NotifiableOffer
    attr_accessor :edited_by

    # for talent app audit 
    def common_options(user, user_agent)
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: nil,
        from: user,
        read: true,
        viewed_or_emailed: true,
        visibility: nil
      }
      options[:created_at] = options[:updated_at] = Time.now
      options
    end

    def send_notification_for_sent_offer(user, user_agent, child_obj)
      user = user || updated_by
      # we dont need ip so no required to send user_agent
      options = common_options(user, nil)
      talent = talents_job.talent
      options.merge!({
        key: nil,
        label: nil,
        message: "Document was Sent to #{talent.name}, #{talent.email}",
      })
      notification = Notification.create(options)
    end

    def send_notification_for_view_offer(talent, user_agent, child_obj)
      options = common_options(talent, user_agent)
      options.merge!({
        key: nil,
        label: nil,
        message: "Document was Viewed",
      })
      notification = Notification.create(options)
    end

    def send_notification_for_signing_offer(talent, user_agent, child_obj)
      options = common_options(talent, user_agent)
      options.merge!({
        key: nil,
        label: nil,
        message: "Document was Signed",
      })
      notification = Notification.create(options)
    end

    def send_notification_for_offer_reject(talent, user_agent, child_obj)
      options = common_options(talent, user_agent)
      options.merge!({
        key: nil,
        label: nil,
        message: "Document was Rejected",
      })
      notification = Notification.create(options)
    end
  end
end