module Notifiable
  module NotifiableRtr

    def send_notification_for_rtr(changed_fields, user, user_agent, changes=nil)
      return if signed_at && talents_job.all_rtr.signed.count <= 1
      return if rejected_at && talents_job.withdrawn
      self.edited_by = updated_by
      job = talents_job.job
      talent = talents_job.talent
      recipients = { object: talents_job, from: edited_by}
      recipients_without_talent = { object: talents_job, from: edited_by}
      recipient_for_activity_by_talent = { object: talents_job, from: talent}
      rtr_obj = { talents_job: talents_job.id, rtr: id, type: 'Rtr' }
      if changes && changed_fields.include?('Id') && changed_fields.include?('Updated by') && talents_job.all_rtr.count > 1
        if completed_transition.stage == 'Invited'
          send_notifications(
            recipients,
            NotificationEvent.get_event('Reinvited'),
            talents_job.notify_objects,
            'resend_rtr',
            'RTR Resend',
            user_agent, self,
            rtr_obj
          )
          send_notification_for_resent_rtr(user, user_agent, nil)
        else
          send_notifications(
            recipients,
            NotificationEvent.get_event('Resend RTR'),
            talents_job.notify_objects,
            'resend_rtr',
            'RTR Resend',
            user_agent, self,
            rtr_obj
          )
          send_notification_for_resent_rtr(user, user_agent, nil)
        end
        Message::TalentsJobMessageService.resend_rtr(user, completed_transition)

      elsif changed_fields.include?('Viewed')
        recipient_for_activity_by_talent = {object: talents_job, from: talent}
        send_notifications(
          recipient_for_activity_by_talent,
          NotificationEvent.get_event('Candidate read invitation'),
          talents_job.notify_objects,
          'candidatesjob_read_invitation',
          'Candidate Read Invitation',
          user_agent, self,
          rtr_obj
        )
      elsif changed_fields.include?('Signed at')
        send_notifications(
          recipient_for_activity_by_talent,
          NotificationEvent.get_event('Revised RTR Signed'),
          talents_job.notify_objects,
          'candidatesjob_approved',
          'RTR Accepted',
          user_agent, self,
          rtr_obj
        )
        send_notification_for_signing_rtr(talents_job.talent, user_agent, nil)
        TalentsJobMailer.candidate_signed_rtr(talents_job).deliver_now
        TalentMailer.account_verify_notify(talents_job.talent).deliver_now unless talents_job.talent.verified
      elsif changed_fields.include?('Rejected at') && !rejected_by_system
        send_notifications(
          recipient_for_activity_by_talent,
          NotificationEvent.get_event('Revised RTR Declined'),
          talents_job.notify_objects.merge(reject_reason: reject_reason),
          'candidatesjob_rejected',
          'RTR Declined',
          user_agent, self,
          rtr_obj
        )
        send_notification_for_rejected_rtr(talents_job.talent, user_agent, nil)
        TalentMailer.account_verify_notify(talents_job.talent).deliver_now unless talents_job.talent.verified
      end
    end

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

    def send_notification_for_sent_rtr(user, user_agent, child_obj)
      user = user || updated_by || talents_job.latest_transition_obj.updated_by
      # we dont need ip so no required to send user_agent
      options = common_options(user, nil)
      talent = talents_job.talent
      options.merge!({
        key: nil,
        label: nil,
        message: "Document was Sent to #{talent.name}, #{talent.email}",
      })
      Notification.create(options)
    end

    def send_notification_for_view_rtr(talent, user_agent, child_obj)
      options = common_options(talent, user_agent)
      options.merge!({
        key: nil,
        label: nil,
        message: "Document was Viewed",
      })
      Notification.create(options)
    end

    def send_notification_for_signing_rtr(talent, user_agent, child_obj)
      options = common_options(talent, user_agent)
      options.merge!({
        key: nil,
        label: nil,
        message: "Document was Signed",
      })
      Notification.create(options)
    end

    def send_notification_for_rejected_rtr(talent, user_agent, child_obj)
      options = common_options(talent, user_agent)
      options.merge!({
        key: nil,
        label: nil,
        message: "Document was Rejected",
      })
      Notification.create(options)
    end

    def send_notification_for_resent_rtr(user, user_agent, child_obj)
      user = user || updated_by || talents_job.latest_transition_obj.updated_by
      # we dont need ip so no required to send user_agent
      options = common_options(user, nil)
      talent = talents_job.talent
      options.merge!({
        key: nil,
        label: nil,
        message: "Document was Resent to #{talent.name}, #{talent.email}",
      })
      Notification.create(options)
    end

    def send_notification_for_self_applied_rtr(talent, user_agent, child_obj)
      options = common_options(talent, user_agent)
      options.merge!({
        key: nil,
        label: nil,
        message: "Document was Signed",
      })
      Notification.create(options)
    end

    def send_notifications_for_bill_rate_negotiation(status, timeline)
      requested_by = bill_rate_negotiation.proposed_by
      account_manager = talents_job.job.account_manager
      hiring_manager = talents_job.job.hiring_manager

      case status
      when 'bill_rate_requested'
        action_by = requested_by
        notify_users = notifiable_users(requested_by)
        if requested_by.agency_user?
          notify_users.each do |user|
            RtrMailer.notify_manager_bill_rate_requested(
              bill_rate_negotiation,
              user
            ).deliver_now

            in_app_notification_bill_rate(status, user, timeline)
          end
        else
          RtrMailer.notify_recruiter_bill_rate_requested(
            bill_rate_negotiation,
            talents_job.user
          ).deliver_now
          in_app_notification_bill_rate(status, talents_job.user, timeline)

          if requested_by.internal_user? && hiring_manager.present?
            in_app_notification_bill_rate('send_change_rate_info', hiring_manager, timeline)
          elsif requested_by.hiring_org_user?
            in_app_notification_bill_rate('send_change_rate_info', account_manager, timeline)
          end
        end

      when 'bill_rate_cancelled'
        action_by = bill_rate_negotiation.rejected_by
        notify_users = notifiable_users(action_by)

        notify_users.each do |user|
          in_app_notification_bill_rate(status, user, timeline)
          if requested_by.agency_user?
            RtrMailer.notify_manager_bill_rate_cancelled(
              bill_rate_negotiation,
              user
            ).deliver_now
          else
            RtrMailer.notify_recruiter_bill_rate_cancelled(
              bill_rate_negotiation,
              user
            ).deliver_now
          end
        end

      when 'bill_rate_declined'
        action_by = bill_rate_negotiation.rejected_by
        notify_users = notifiable_users(action_by)

        notify_users.each do |user|
          RtrMailer.notify_bill_rate_declined(bill_rate_negotiation, user).deliver_now
          in_app_notification_bill_rate(status, user, timeline)
        end

      when 'bill_rate_approved'
        action_by = bill_rate_negotiation.approved_by
        notify_users = notifiable_users(action_by)
        notify_users.each do |user|
          if bill_rate_negotiation.if_declined_and_proposed.is_true?
            RtrMailer.notify_proposed_bill_rate_approved(
              bill_rate_negotiation,
              user,
            ).deliver_now
          else
            RtrMailer.notify_bill_rate_approved(
              bill_rate_negotiation,
              user,
            ).deliver_now
          end
          in_app_notification_bill_rate(status, user, timeline)
        end

      when 'bill_rate_declined_proposed'
        bill_rate = bill_rate_negotiation.declined_rate
        action_by = bill_rate.rejected_by
        notify_users = notifiable_users(action_by)
        notify_users.each do |user|
          RtrMailer.notify_bill_rate_declined_proposed(bill_rate_negotiation, user).deliver_now
          in_app_notification_bill_rate(status, user, timeline)
        end
      end

      NotifyAgencyUsersBillRateJob.perform_now(
        talents_job.user,
        status,
        self,
        action_by.id,
        notify_users.pluck(:id),
        timeline
      )
    end

    def send_notifications_for_bill_rate_cs_candidate(status, timeline)
      case status
      when 'bill_rate_requested'
        notify_users = notifiable_users(bill_rate_negotiation.proposed_by)
        RtrMailer.notify_recruiter_bill_rate_requested(
          bill_rate_negotiation,
          notify_users
        ).deliver_now

        in_app_notification_bill_rate(status, notify_users, timeline)

      when 'bill_rate_cancelled'
        notify_users = notifiable_users(bill_rate_negotiation.rejected_by)
        RtrMailer.notify_manager_bill_rate_cancelled(
          bill_rate_negotiation,
          notify_users
        ).deliver_now

        in_app_notification_bill_rate(status, notify_users, timeline)

      when 'bill_rate_approved'
        notify_users = notifiable_users(bill_rate_negotiation.approved_by)
        RtrMailer.notify_bill_rate_approved(
          bill_rate_negotiation,
          notify_users,
        ).deliver_now

        in_app_notification_bill_rate(status, notify_users, timeline)

      when 'bill_rate_declined'
        notify_users = notifiable_users(bill_rate_negotiation.rejected_by)
        RtrMailer.notify_bill_rate_declined(bill_rate_negotiation, notify_users).deliver_now
        in_app_notification_bill_rate(status, notify_users, timeline)
        
      when 'bill_rate_declined_proposed'
        bill_rate = bill_rate_negotiation.declined_rate
        notify_users = notifiable_users(bill_rate.rejected_by)
        RtrMailer.notify_bill_rate_declined_proposed(
          bill_rate_negotiation,
          notify_users
        ).deliver_now

        in_app_notification_bill_rate(status, notify_users, timeline)
      end
    end

    def timeline_entry_for_bill_rate_negotiation(status)
      job = talents_job.job
      hiring_manager = job.hiring_manager
      account_manager = job.account_manager
      talent_supplier = talents_job.user

      case status
      when 'bill_rate_requested'
        note = bill_rate_negotiation.proposed_note
        user = bill_rate_negotiation.proposed_by

        if talents_job.recruiter_incumbent?
          if user.agency_user?
            approval = "#{user_details(account_manager)}"
            if hiring_manager.present?
              approval += ", #{user_details(hiring_manager)}"
            end
          else
            approval = "#{user_details(talent_supplier)}"
          end
        else
          get_approval_from = user.internal_user? ? hiring_manager : account_manager
          approval = "#{user_details(get_approval_from)}"
        end

        key = 'bill_rate_requested'
        label = 'Bill Rate - Updated'
        message = "#{user_details(user)} has requested a <b>bill rate</b> change for " \
          "<a href='#{FE_HOST}#/talent-pool/#{talent.id}?tab=profile'>#{talent.name.titleize}</a>" \
          " from #{job.get_currency_symbol.html_safe}#{'%.2f' % confirmed_bill_rate}/hr to " \
          "#{job.get_currency_symbol.html_safe}#{'%.2f' % bill_rate_negotiation.value}/hr.<br>"
        message += "Note: #{note}<br>" if note.present?
        message += "<br>Waiting for approval from #{approval}"

      when 'bill_rate_cancelled'
        note = bill_rate_negotiation.reject_note
        user = bill_rate_negotiation.rejected_by
        key = 'bill_rate_cancel'
        label = 'Bill Rate Cancelled'
        message = "#{user_details(user)} has cancelled a <b>bill rate</b> change for " \
          "<a href='#{FE_HOST}#/talent-pool/#{talent.id}?tab=profile'>#{talent.name.titleize}</a>"
        message += "<br>Note: #{note}" if note.present?

      when 'bill_rate_declined'
        note = bill_rate_negotiation.reject_note
        user = bill_rate_negotiation.rejected_by
        key = 'bill_rate_decline'
        label = 'Bill Rate Declined'
        rate = if bill_rate_negotiation.if_declined_and_proposed.is_true?
                 "#{user_details(user)} has declined the proposed bill rate change for "
               else
                 "#{user_details(user)} has declined the <b>bill rate</b> change for "
               end
        message = rate + "<a href='#{FE_HOST}#/talent-pool/#{talent.id}?tab=profile'>" \
          "#{talent.name.titleize}</a> from " \
          "#{job.get_currency_symbol.html_safe}#{'%.2f' % confirmed_bill_rate}/hr to" \
          " #{job.get_currency_symbol.html_safe}#{'%.2f' % bill_rate_negotiation.value}/hr."
        message += "<br>Note: #{note}" if note.present?

      when 'bill_rate_approved'
        note = bill_rate_negotiation.approve_note
        user = bill_rate_negotiation.approved_by
        key = 'bill_rate_approved'
        label = 'Bill Rate Accepted'
        rate = if bill_rate_negotiation.if_declined_and_proposed.is_true?
                 "#{user_details(user)} has accepted the new proposed bill rate change for "
               else
                 "#{user_details(user)} has accepted the <b>bill rate</b> change for "
               end
        message = rate + "<a href='#{FE_HOST}#/talent-pool/#{talent.id}?tab=profile'>" \
          "#{talent.name.titleize}</a> from " \
          "#{job.get_currency_symbol.html_safe}#{'%.2f' % bill_rate_negotiation.last_bill_rate}" \
          "/hr to #{job.get_currency_symbol.html_safe}#{'%.2f' % bill_rate_negotiation.value}/hr."
        message += "<br>Note: #{note}" if note.present?

      when 'bill_rate_declined_proposed'
        note = bill_rate_negotiation.proposed_note
        user = bill_rate_negotiation.proposed_by
        key = 'bill_rate_proposed'
        label = 'New Bill Rate Proposed'
        message = "#{user_details(user)} has declined the <b>bill rate</b> change for " \
          "<a href='#{FE_HOST}#/talent-pool/#{talent.id}?tab=profile'>#{talent.name.titleize}</a>" \
          " from #{job.get_currency_symbol.html_safe}#{'%.2f' % confirmed_bill_rate}/hr to "\
          "#{job.get_currency_symbol.html_safe}" \
          "#{'%.2f' % bill_rate_negotiation.declined_rate.value}/hr.<br>" \
          "Proposed new rate: #{job.get_currency_symbol.html_safe}" \
          "#{'%.2f' % bill_rate_negotiation.value}/hr. "
        message += "<br>Note: #{note}" if note.present?
      end

      options = {
        show_on_timeline: true,
        object: talents_job,
        receiver: talents_job,
        key: key,
        label: label,
        message: message,
        created_at: Time.now,
        updated_at: Time.now,
        specific_obj: { bill_rate_negotiation: bill_rate_negotiation.id },
      }

      notification = Notification.create(options) if options
      notification
    end

    def in_app_notification_bill_rate(status, user, timeline)
      job = talents_job.job
      declined_and_proposed = bill_rate_negotiation.if_declined_and_proposed.is_true? &&
          bill_rate_negotiation.declined_rate.if_declined_and_proposed.is_true?

      case status
      when 'bill_rate_requested'
        from = bill_rate_negotiation.proposed_by
        proposed_by_user = from
        key = 'bill_rate_request'
        message = "Action Required: Bill rate updated for <a href='#{base_url(user)}#/recruiting" \
          "-job/#{talents_job.job.id}?stage=#{talents_job.stage}&talent_job_id=#{talents_job.id}'" \
          ">#{talents_job.talent.name.titleize}</a>"

      when 'bill_rate_cancelled'
        from = bill_rate_negotiation.rejected_by
        rejected_by_user = from
        key = 'bill_rate_cancel'
        message = "Bill rate cancelled for <a href='#{base_url(user)}#/recruiting-job/" \
          "#{talents_job.job.id}?stage=#{talents_job.stage}&talent_job_id=#{talents_job.id}'>" \
          "#{talents_job.talent.name.titleize}" \
          "</a>"

      when 'bill_rate_declined'
        from = bill_rate_negotiation.rejected_by
        rejected_by_user = from
        key = 'bill_rate_decline'
        message = if talents_job.user.internal_user?
                    "Bill-rate change on "
                    "<a href='#{base_url(user)}#/recruiting-job/#{talents_job.job.id}?stage=" \
                    "#{talents_job.stage}&talent_job_id=#{talents_job.id}'>" \
                    "#{talents_job.job.title}</a> position at " \
                    "#{talents_job.job.client.company_name.titleize} was declined"
                  else
                    "#{from.name.titleize} has declined bill rate change for " \
                    "<a href='#{base_url(user)}#/recruiting-job/#{talents_job.job.id}?stage=" \
                    "#{talents_job.stage}&talent_job_id=#{talents_job.id}'>" \
                    "#{talents_job.talent.name.titleize}</a>"
                  end

      when 'bill_rate_approved'
        from = bill_rate_negotiation.approved_by
        approved_by_user = from
        key = 'bill_rate_approved'
        message = "#{from.name.titleize} has accepted bill rate change for " \
          "<a href='#{base_url(user)}#/recruiting-job/#{talents_job.job.id}?stage=" \
          "#{talents_job.stage}&talent_job_id=#{talents_job.id}'>" \
          "#{talents_job.talent.name.titleize}</a>"
      when 'send_change_rate_info'
        from = bill_rate_negotiation.proposed_by
        proposed_by_user = from
        key = 'bill_rate_request_info'
        message = "Bill rate updated for <a href='#{base_url(user)}#/recruiting-job/" \
          "#{talents_job.job.id}?stage=#{talents_job.stage}&talent_job_id=#{talents_job.id}'>" \
          "#{talents_job.talent.name.titleize}" \
          "</a>"
      when 'bill_rate_declined_proposed'
        from = bill_rate_negotiation.proposed_by
        proposed_by_user = from
        key = 'bill_rate_proposed'
        message = if talents_job.user.internal_user?
                    "Bill-rate change on " \
                    "<a href='#{base_url(user)}#/recruiting-job/#{talents_job.job.id}?stage=" \
                    "#{talents_job.stage}&talent_job_id=#{talents_job.id}'>" \
                    "#{talents_job.job.title}</a> position at " \
                    "#{talents_job.job.client.company_name.titleize} was not accepted"
                  elsif declined_and_proposed
                    "Bill-rate change on #{talents_job.job.title} position at " \
                    "#{talents_job.client.company_name} was not accepted <br>" \
                    "#{from.name.titleize} has proposed bill rate change for "\
                    "<a href='#{base_url(user)}#/recruiting-job/#{talents_job.job.id}?stage=" \
                    "#{talents_job.stage}&talent_job_id=#{talents_job.id}'>" \
                    "#{talents_job.talent.name.titleize}</a> from " \
                    "#{job.get_currency_symbol.html_safe}" \
                    "#{'%.2f' % confirmed_bill_rate}/hr to " \
                    "#{job.get_currency_symbol.html_safe}#{'%.2f' % bill_rate_negotiation.value}/hr"
                  else
                    "#{from.name.titleize} has proposed bill rate change for "\
                    "<a href='#{base_url(user)}#/recruiting-job/#{talents_job.job.id}?stage=" \
                    "#{talents_job.stage}&talent_job_id=#{talents_job.id}'>" \
                    "#{talents_job.talent.name.titleize}</a> from " \
                    "#{job.get_currency_symbol.html_safe}" \
                    "#{'%.2f' % confirmed_bill_rate}/hr to " \
                    "#{job.get_currency_symbol.html_safe}#{'%.2f' % bill_rate_negotiation.value}/hr"
                  end
      end

      user_status = if user.can?(:approve, bill_rate_negotiation)
                      'review'
                    else
                      bill_rate_negotiation.get_status(user)
                    end
      timeline_message = if user.internal_user?
                           timeline.message
                         else
                           ActionController::Base.helpers.sanitize(
                             timeline.message,
                             tags: ['b', 'div', 'img', 'br']
                           )
                         end
      declined_rate = {}
      bill_rate = bill_rate_negotiation.declined_rate
      if bill_rate.present?
        declined_rate = {
          value: bill_rate.value,
          rejected_by: {
            first_name: bill_rate.rejected_by.first_name,
            last_name: bill_rate.rejected_by.last_name,
            primary_role: bill_rate.rejected_by.primary_role,
          },
        }
      end

      options = {
        object: bill_rate_negotiation,
        receiver: user,
        from: from,
        key: key,
        message: message,
        created_at: Time.now,
        updated_at: Time.now,
        show_on_timeline: false,
        specific_obj: {
          talents_job_id: talents_job.id,
          job_id: talents_job.job.id,
          timeline: {
            id: timeline.id,
            key: timeline.key,
            label: timeline.label,
            message: timeline_message,
            agency_id: timeline.agency_id,
            created_at: timeline.created_at,
            object_id: timeline.object.id,
            object_type: timeline.object_type,
            receiver_id: timeline.receiver.id,
            receiver_type: timeline.receiver_type,
            show_on_timeline: timeline.show_on_timeline,
            updated_at: timeline.updated_at,
            specific_obj: timeline.specific_obj,
            accept_bill_rate: user.can?(:approve, bill_rate_negotiation),
            decline_bill_rate: user.can?(:decline, bill_rate_negotiation),
            cancel_bill_rate: user.can?(:cancel, bill_rate_negotiation),
          },
          user_status: user_status,
          bill_rate_negotiation: {
            id: bill_rate_negotiation.id,
            approved_by: approved_by_user,
            rejected_by: rejected_by_user,
            value: bill_rate_negotiation.value,
            proposed_by: proposed_by_user,
            proposed_note: bill_rate_negotiation.proposed_note,
            status: bill_rate_negotiation.status,
            approve_note: bill_rate_negotiation.approve_note,
            reject_note: bill_rate_negotiation.reject_note,
            declined_rate: declined_rate,
            last_bill_rate: bill_rate_negotiation.last_bill_rate,
          },
        },
      }
      n = Notification.create(options)
      n.send(:pusher_notification)
    end

    def user_details(user)
      details = if user.avatar
                  "<img src='#{user.avatar}' class='timeline-avatar-img'>"
                else
                  avatar = "<div class='timeline-avatar' " \
                    "style='background-color: #{GetAvatar.get_bg_color(user.name)};'>" \
                    "#{user.first_name[0].upcase}#{user.last_name[0].upcase}</div>"
                  avatar
                end
      details + if user.account_manager?
                  "<a href='#{FE_HOST}#/account-managers/#{user.id}'>#{user.name.titleize}</a>"
                elsif user.internal_user?
                  "<a href='#{FE_HOST}#/users/#{user.id}'>#{user.name.titleize}</a>"
                elsif user.agency_user?
                  "<a href='#{FE_HOST}#/member/#{user.id}'>#{user.name.titleize}</a>"
                elsif user.hiring_org_user?
                  "<a href='#{FE_HOST}#/ho-member/#{user.id}'>#{user.name.titleize}</a>"
                end
    end

    def notifiable_users(user)
      hiring_manager = talents_job.job.hiring_manager
      account_manager = talents_job.job.account_manager
      talent_supplier = talents_job.user
      notify_users = []

      if talents_job.recruiter_incumbent?
        if user.internal_user?
          notify_users << hiring_manager if hiring_manager.present?
          notify_users << talent_supplier
        elsif user.agency_user?
          notify_users << hiring_manager if hiring_manager.present?
          notify_users << account_manager
        elsif user.hiring_org_user?
          notify_users << account_manager
          notify_users << talent_supplier
        end
      elsif talents_job.user.internal_user?
        notify_users = user.internal_user? ? hiring_manager : account_manager
      end

      notify_users
    end

    def base_url(user)
      user.hiring_org_user? ? FE_HOST.gsub(/app\./, 'enterprise.') : FE_HOST
    end
  end
end
