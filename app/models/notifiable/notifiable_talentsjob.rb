module Notifiable
  module NotifiableTalentsjob
    attr_accessor :edited_by

    def send_notification_for_talentsjob(changed_fields, user, user_agent, changes = nil)
      self.edited_by = user
      return if (changed_fields & %w(Stage Rejected Withdrawn Interested User)).empty?
      recipients = { object: self, from: edited_by }

      recipients_without_talent = { object: self, from: edited_by }

      recipient_for_activity_by_talent = { object: self, from: talent }

      offer_letter_obj = { talents_job: id, offer_letter: offer_letter.try(:id), type: 'Offer' }

      assignment_detail_obj = { talents_job: id, assignment_detail: assignment_detail&.id, type: 'Assignment Detail' }

      if changed_fields.include?('Rejected') && rejected && rejected_by.is_a?(Talent)
        label = 'Job offer rejected by talent'
        send_notifications(
          { object: self, from: edited_by },
          NotificationEvent.get_event(label),
          {
            job_id: job.id, job_title: job.title,
            rejected_by: rejected_by.try(:first_name),
            stage: stage, reason_to_reject: primary_disqualify_reason,
            talent_id: talent.id, talent_name: talent.name,
            reason_notes: reason_notes,
          },
          'candidatesjob_rejected',
          'Candidate Rejected Job Offer',
          user_agent,
          self
        )

      elsif changed_fields.include?('Withdrawn') && withdrawn
        return if job.nil? || talent.nil? || withdrawn_by.is_a?(User)
        self.edited_by = nil if withdrawn_by.nil?
        label = (withdrawn_by == talent ? 'Job offer withdrawn by talent' :
          'Job offer withdrawn by other')
        label = 'Job offer auto withdrawn' if withdrawn_by.nil?
        recipients[:from] = recipient_for_activity_by_talent[:from] = nil if withdrawn_by.nil?
        withdrawn_by = withdrawn_by.nil? ? nil : withdrawn_by.try(:first_name)
        send_notifications(
          (withdrawn_by == talent ? recipient_for_activity_by_talent : recipients),
          NotificationEvent.get_event(label),
          {
           job_id: job.id, job_title: job.title,
           withdrawn_by: withdrawn_by.try(:first_name), stage: stage,
           reason_to_withdrawn: reason_to_withdrawn,
           withdrawn_notes: withdrawn_notes,
           talent_id: talent.id, talent_name: talent.name,
           team_member: self.user.try(:username), team_member_id: user_id,
          },
          'candidatesjob_withdrawn',
          withdrawn_by.is_a?(Talent) ? 'Job Offer Withdrawn' : 'Candidate Withdrawn',
          user_agent,
          self
        )
      elsif changed_fields.include?("Interested") && interested
        send_notifications(
          recipient_for_activity_by_talent,
          NotificationEvent.get_event('Candidate interested'),
          notify_objects,
          "candidatesjob_applied_to_job",
          "Applied To Job",
          user_agent,
          self
        )

        TalentMailer.account_verify_notify(talent).deliver_later unless talent.verified
      elsif changed_fields.include?("User") &&
          !["Sourced", "Invited"].include?(stage)
        send_notifications(
          recipient_for_activity_by_talent,
          NotificationEvent.get_event('Recruiter assigned to Job'),
          {
           job_id: job.id,
           job_title: job.title,
           team_member_name: self.user.first_name,
           team_member_id: self.user.id,
           talent_id: talent.id,
           talent_name: talent.name,
           user_variable: 'member',
          },
          'candidatesjob_recruiter_assigned',
          'Recruiter Assigned To Candidate',
          user_agent,
          self
        )

      elsif changed_fields.include?('Rejected') && reinstate_by.present?
      elsif changed_fields.include?('Stage')
        case stage
        when 'Sourced'
          # refer ---> candidate_sourced
        when 'Invited'
          event_name = "Representation letter"
          send_notifications(
            recipients,
            NotificationEvent.get_event(event_name),
            notify_objects,
            'candidatesjob_invited',
            'Candidate Invited',
            user_agent, self,
            { talents_job: id, rtr: pending_rtr.id, type: 'Rtr' }
          )

          pending_rtr.send_notification_for_sent_rtr(user, user_agent, nil)
          if all_rtr.count == 1
            Message::TalentsJobMessageService.candidate_invited(user, latest_transition_obj)
          end
        when 'Signed'
          if offline? || rtr.offline?
            send_notifications(
              recipient_for_activity_by_talent,
              NotificationEvent.get_event('Offline Job Signed'),
              notify_objects,
              'candidatesjob_signed',
              'Offline RTR signed',
              user_agent, self,
              { talents_job: id, rtr: rtr.id, type: 'Rtr' }
            )

          else
            send_notifications(
              recipient_for_activity_by_talent,
              NotificationEvent.get_event('Job Signed'),
              notify_objects,
              'candidatesjob_signed',
              'RTR signed',
              user_agent, self,
              { talents_job: id, rtr: rtr.id, type: 'Rtr' }
            )

            rtr.send_notification_for_signing_rtr(talent, user_agent, nil)
          end
          TalentMailer.account_verify_notify(talent).deliver_later unless talent.verified
        when 'Submitted'
          if interested
            send_notifications(
              recipient_for_activity_by_talent,
              NotificationEvent.get_event('Candidate interested'),
              notify_objects,
              'candidatesjob_applied_to_job',
              'Applied To Job',
              user_agent,
              self,
              { talents_job: id, rtr: rtr.id, type: 'Rtr' }
            )

            TalentMailer.account_verify_notify(talent).deliver_later unless talent.verified
          end

          if offline? || rtr.offline?
            send_notifications(
              recipient_for_activity_by_talent,
              NotificationEvent.get_event('Offline Job Submitted'),
              notify_objects,
              'candidatesjob_submitted',
              'Offline RTR signed',
              user_agent, self,
              { talents_job: id, rtr: rtr.id, type: 'Rtr' }
            )
          else
            send_notifications(
              recipient_for_activity_by_talent,
              NotificationEvent.get_event('Auto Submitted'),
              notify_objects,
              'candidatesjob_submitted',
              'Candidate Submitted',
              user_agent,
              self,
              { talents_job: id, rtr: rtr.id, type: 'Rtr' }
            )

            options = {
              show_on_timeline: false,
              user_agent: user_agent,
              object: self,
              key: 'candidatesjob_submitted',
              label: 'Candidate Submitted',
              message: "<a href='/#/talent-pool/#{talent_id}?tab=profile'>#{talent&.name}</a> has signed RTR with #{self.user&.name} and moved to <b>Submitted</b> stage",
              receiver: nil,
              from: nil,
              read: true,
              viewed_or_emailed: true,
              visibility: nil,
              created_at: Time.now,
              updated_at: Time.now,
            }

            # pusher notification
            batch = []
            [job.account_manager, self.user, invited_obj&.updated_by].compact.uniq.each do |user|
              o = options.dup
              o['receiver_id'] = user.id
              o['receiver_type'] = 'User'
              o.delete('id')
              batch << o
            end

            if batch.present?
              insert_many = Notification.create(batch)
              insert_many.each { |n| n.send(:pusher_notification) if n.persisted? }
            end

            rtr.send_notification_for_signing_rtr(talent, user_agent, nil)
            TalentMailer.account_verify_notify(talent).deliver_later unless talent.verified
          end
        when 'Hired'
          candidate_accepted_offer(user_agent)
        when 'Assignment Begins'
          send_notifications(
            recipients,
            NotificationEvent.get_event('Candidate moved'),
            {
              job_id: job.id,
              job_title: job.title,
              changed_by: edited_by.try(:first_name),
              talent_id: talent.id,
              talent_name: talent.name,
              stage: stage,
              note: completed_transitions.where(stage: stage).last&.note
            },
            "candidatesjob_" +
              job.recruitment_pipeline.pipeline_steps.where(stage_label: stage).first.stage_type.
              downcase.split(' ').join('_'),
            stage,
            user_agent,
            self,
            assignment_detail_obj
          )
        when 'Assignment Ends'
          send_notifications(
            recipients,
            NotificationEvent.get_event('Assignment Ended'),
            {
              job_id: job.id,
              job_title: job.title,
              talent_id: talent.id,
              talent_name: talent&.name,
              note: [assignment_detail&.primary_end_reason, assignment_detail&.secondary_end_reason].join('-'),
              profile_id: talent&.get_profile_for(edited_by)&.id,
              assignment_end_date: assignment_detail&.end_date&.strftime("%B %d, %Y"),
            },
            "candidatesjob_" +
               job.recruitment_pipeline.pipeline_steps.where(stage_label: stage).
               first.stage_type.downcase.split(' ').join('_'),
            'Assignment Ended',
            user_agent,
            self,
            assignment_detail_obj
          )
        else
          if latest_transition_obj.event
            event_scheduled_talentsjob(changed_fields, user, user_agent)
          else
            is_stage = stage == 'On-boarding'
            notifiers = is_stage ? recipients : recipients_without_talent
            unless stage == 'Offer'
              send_notifications(
                notifiers,
                NotificationEvent.get_event('Candidate moved'),
                {
                  job_id: job.id, job_title: job.title,
                  changed_by: edited_by.try(:first_name),
                  talent_id: talent.id, talent_name: talent.name,
                  stage: stage,
                  note: completed_transitions.where(stage: stage).last&.note
                },
                "candidatesjob_" +
                job.recruitment_pipeline.pipeline_steps.where(stage_label: stage).
                first.stage_type.downcase.split(' ').join('_'),
                stage,
                user_agent,
                self
              )
            end
          end
        end
      end
    end

    def offer_letter_rejected(changed_fields, user, user_agent)
      # do not change self.user.find_admins to user.find_admins or user.try ..
      recipient_for_activity_by_talent = {
        object: self, from: talent,
      }

      offer_letter_obj = {
        talents_job: id, offer_letter: offer_letter.try(:id), type: 'Offer',
      }

      send_notifications(
        recipient_for_activity_by_talent,
        NotificationEvent.get_event('Letter of offer declined'),
        notify_objects,
        'candidatesjob_offer_declined',
        'Letter Of Offer Declined',
        user_agent, self,
        offer_letter_obj
      )
      TalentsJobMailer.candidate_rejected_letter_of_offer(self).deliver_now
      TalentMailer.account_verify_notify(talent).deliver_later unless talent.verified
      offer_letter.send_notification_for_offer_reject(talent, user_agent, nil)
    end

    def offer_letter_rejected_by_admin(changed_fields, user, user_agent)
      # do not change self.user.find_admins to user.find_admins or user.try ..
      recipient_for_activity_by_talent = {
        object: self, from: user,
      }

      offer_letter_obj = {
        talents_job: id, offer_letter: offer_letter.try(:id), type: 'Offer',
      }

      send_notifications(
        recipient_for_activity_by_talent,
        NotificationEvent.get_event('Letter of offer withdrawn'),
        notify_objects,
        'candidatesjob_offer_declined',
        'Letter Of Offer Withdrawn',
        user_agent, self,
        offer_letter_obj
      )
      TalentsJobMailer.candidate_rejected_letter_of_offer(self).deliver_now
      TalentMailer.account_verify_notify(talent).deliver_later unless talent.verified
    end

    def event_scheduled_talentsjob(changed_fields, user, user_agent)
      assoc_job = job
      assoc_talent = talent
      event = events.last
      if event.start_date_time
        timezone = Timezone.find_by_name("Pacific Standard Time")
        start_time = timezone.get_dst_time(event.start_date_time.to_time).strftime("%B %d, %Y %I:%M %p").concat(" #{timezone[:abbr]}")
        end_time = timezone.get_dst_time(event.end_date_time.to_time).strftime("%B %d, %Y %I:%M %p").concat(" #{timezone[:abbr]}")
      end
      recipients = {
        object: self, from: edited_by,
      }
      send_notifications(
        recipients,
        NotificationEvent.get_event('Candidate moved with event'),
        {
          job_id: assoc_job.id, job_title: assoc_job.title,
          changed_by: user.try(:name),
          talent_id: assoc_talent.id, talent_name: assoc_talent.name,
          stage: stage,
          given_date_time: event.start_date_time ? "#{start_time} to #{end_time}" : "",
        },
        'candidatesjob_event',
        'Candidate Moved With Event',
        user_agent, self
      )
      event_type = event.start_date_time ? "Scheduled" : "requested"
    end

    def invitation_read(changed_fields, user, user_agent)
      rtr.send_notification_for_view_rtr(talent, user_agent, nil)
      rtr_obj = { talents_job: id, rtr: pending_rtr.id, type: 'Rtr' }
      send_read_notification(user,
                             user_agent,
                             'Candidate read invitation',
                             rtr_obj)
    end

    def offer_letter_read(changed_fields, user, user_agent)
      offer_letter_obj = {
        talents_job: id, offer_letter: offer_letter.try(:id), type: 'Offer',
      }
      send_read_notification(user, user_agent, 'Candidate read offer', offer_letter_obj)
      offer_letter.send_notification_for_view_offer(talent, user_agent, nil)
    end

    def onboarding_read(changed_fields, user, user_agent)
      send_read_notification(user, user_agent, 'Candidate read onboarding')
    end

    def send_read_notification(user, user_agent, label, options = {})
      self.edited_by = self.user
      # do not change self.user.find_admins to user.find_admins or user.try ..
      recipient_for_activity_by_talent = { object: self, from: talent }

      send_notifications(
        recipient_for_activity_by_talent,
        NotificationEvent.get_event(label),
        notify_objects,
        "candidatesjob_#{label.split('Candidate ').last.gsub(' ', '_')}",
        label,
        user_agent, self,
        options
      )
    end

    def tags_changed(class_name, changed, obj)
      return unless changed.include?('Tag')
      case obj.stage
      when 'Offer'
        case obj.tag
        when 'declined'
          if obj.updated_by_type == 'User'
            NotificationJob.set(wait: 10.seconds).perform_later(
              obj.talents_job.class.to_s,
              obj.talents_job.id,
              'offer_letter_rejected_by_admin',
              [],
              LoggedinUser.current_user,
              LoggedinUser.user_agent
            )
          else
            NotificationJob.set(wait: 10.seconds).perform_later(
              obj.talents_job.class.to_s,
              obj.talents_job.id,
              'offer_letter_rejected',
              [],
              LoggedinUser.current_user,
              LoggedinUser.user_agent
            )
          end
        when 'opened', 'viewed'
          NotificationJob.set(wait: 10.seconds).perform_later(
            obj.talents_job.class.to_s,
            obj.talents_job.id,
            'offer_letter_read',
            [],
            LoggedinUser.current_user,
            LoggedinUser.user_agent
          )
        end
      when 'Invited'
        if obj.tag.eql?('opened') || obj.tag.eql?('viewed')
          NotificationJob.set(wait: 10.seconds).perform_later(
            obj.talents_job.class.to_s,
            obj.talents_job.id,
            'invitation_read',
            [],
            LoggedinUser.current_user,
            LoggedinUser.user_agent
          )
        end
      when 'On-boarding'
        return unless obj.tag.eql?('in-progress')
        NotificationJob.set(wait: 10.seconds).perform_later(
          obj.talents_job.class.to_s,
          obj.talents_job.id,
          'onboarding_read',
          [],
          LoggedinUser.current_user,
          LoggedinUser.user_agent
        )
      end
    end

    def send_notification_for_talentsjobs_note(changed_fields, note_id, user, user_agent, changes = nil)
      note = Note.find(note_id)
      # timeline
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: user,
        read: true,
        viewed_or_emailed: true,
        visibility: note.visibility,
      }
      options[:created_at] = options[:updated_at] = Time.now
      if !changed_fields.include?('id')
        options.merge!({
          key: "comment_created",
          label: "Comment Edited",
          message: "Comment '#{note.note}' edited for
          <a href='/#/my-candidates/#{talent_id}'>#{talent.name}</a>
          in <a href='/#/recruiting-job/#{job_id}?tab=pipeline&stage=#{stage}'>#{job.title}</a>
          position at <a href='/#/my-client/#{client_id}'>#{job.client.company_name}</a>",
        })

      elsif note.parent
        options.merge!({
          key: "comment_created",
          label: "Replied to comment",
          message: "Reply on comment '#{note.note}' for
          <a href='/#/my-candidates/#{talent_id}'>#{talent.name}</a> in
          <a href='/#/recruiting-job/#{job_id}?tab=pipeline&stage=#{stage}'>#{job.title}</a>
          position at <a href='/#/my-client/#{client_id}'>#{job.client.company_name}</a>
          has been added.",
        })
      else
        options.merge!({
          key: "comment_created",
          label: "Comment Created",
          message: "Comment '#{note.note}' added to
          <a href='/#/my-candidates/#{talent_id}'>#{talent.name}</a> in
          <a href='/#/recruiting-job/#{job_id}?tab=pipeline&stage=#{stage}'>#{job.title}</a>
          position at <a href='/#/my-client/#{client_id}'>#{job.client.company_name}</a>",
        })
      end
      message = options[:message]
      notification = Notification.create(options)
      # pusher notification
      options = notification.attributes
      batch = []
      options[:show_on_timeline] = false
      if note.announcement.is_true?
        options[:message] = "There is an announcement: '#{note.note}' added to
          <a href='/#/my-candidates/#{talent_id}'>#{talent.name}</a> in
          <a href='/#/recruiting-job/#{job_id}?tab=pipeline&stage=#{stage}'>#{job.title}</a>
          position at #{job.client.company_name}"
      else
        options[:message] = "You have been mentioned in a comment: '#{note.note}' added to
          <a href='/#/my-candidates/#{talent_id}'>#{talent.name}</a> in
          <a href='/#/recruiting-job/#{job_id}?tab=pipeline&stage=#{stage}'>#{job.title}</a>
          position at #{job.client.company_name}"
      end
      options.delete("id")
      note.mentioned.each do |u|
        o = options.dup
        o[:receiver_id] = u.id
        o[:receiver_type] = 'User'
        o.delete('id')
        batch << o
      end
      if note.visibility.include?("CROWDSTAFFING") && !user.account_manager?
        o = options.dup
        o[:message] = message
        o['receiver_id'] = job.account_manager.id
        o['receiver_type'] = 'User'
        o[:visibility] = note.visibility
        o.delete('id')
        batch << o
      end
      if batch.present?
        insert_many = Notification.create(batch)
        insert_many.each { |n| n.send(:pusher_notification) if n.persisted? }
      end
    end

    def send_destroy_notification_for_talentsjobs_note(note, visibility, user, user_agent, changes = nil)
      # timeline
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: user,
        read: true,
        viewed_or_emailed: true,
        visibility: visibility,
      }
      options[:created_at] = options[:updated_at] = Time.now
      options.merge!({
        key: "comment_created",
        label: "Comment Deleted",
        message: "Comment '#{note}' deleted for
        <a href='/#/my-candidates/#{talent_id}'>#{talent.name}</a> in
        <a href='/#/recruiting-job/#{job_id}?tab=pipeline&stage=#{stage}'>#{job.title}</a>
        position at #{job.client.company_name}",
      })
      notification = Notification.create(options)
    end

    def notify_objects
      {
        job_id: job.id, job_title: job.title,
        team_member: user.try(:name),
        talent_id: talent.id, talent_name: talent.try(:name),
      }
    end

    def send_notification_of_apply(user, user_agent)
      recipient_for_activity_by_talent = { object: self, from: talent }

      rtr_hash = rtr ? { talents_job: id, rtr: rtr.id, type: 'Rtr' } : nil

      send_notifications(recipient_for_activity_by_talent,
                         NotificationEvent.get_event('Candidate interested'),
                         notify_objects,
                         "candidatesjob_applied_to_job",
                         "Applied To Job",
                         user_agent,
                         self,
                         rtr_hash)
      TalentMailer.account_verify_notify(talent).deliver_later unless talent.verified
      TalentsJob.find(id)&.rtr.send_notification_for_self_applied_rtr(talent, user_agent, nil)
    end

    def candidate_sourced(user, user_agent)
      self.edited_by = user

      send_notifications(
        {object: self, from: user},
        NotificationEvent.get_event('Candidate sourced'),
        notify_objects,
        'candidatesjob_sourced',
        'Candidate Sourced',
        user_agent,
        self
      )
    end

    def candidate_signed(user, user_agent)
      recipient_for_activity_by_talent = { object: self, from: talent }

      if offline? || rtr.offline?
        send_notifications(
          recipient_for_activity_by_talent,
          NotificationEvent.get_event('Offline Job Signed'),
          notify_objects,
          'candidatesjob_signed',
          'Offline RTR signed',
          user_agent,
          self,
          { talents_job: id, rtr: rtr.id, type: 'Rtr' }
        )
      else
        send_notifications(
          recipient_for_activity_by_talent,
          NotificationEvent.get_event('Job Signed'),
          notify_objects,
          'candidatesjob_signed',
          'RTR signed',
          user_agent,
          self,
          { talents_job: id, rtr: rtr.id, type: 'Rtr' }
        )
      end
      TalentMailer.account_verify_notify(talent).deliver_later unless talent.verified
    end

    ######################## new notification system ########################
    def candidate_withdrawn(login_user, user_agent, obj)
      create_notificaton_for_tj(
        login_user,
        user_agent,
        'candidatesjob_withdrawn',
        'Candidate Withdrawn',
        "Candidate <a href='/#/talent-pool/#{talent.id}?tab=profile'>#{talent.name}</a>
          has been withdrawn for job <a href='/#/recruiting-job/#{job.id}?tab=pipeline'>#{job.title}</a>
          at stage <b>'#{stage}'</b> for reason <b>#{reason_to_withdrawn}</b>,
          note: <b>#{withdrawn_notes}</b>",
        user
      )

      Message::TalentsJobMessageService.notify_candidate_withdrawn(login_user, user, self)
    end

    def candidate_withdrawn_by_recruiter(login_user, user_agent, obj)
      create_notificaton_for_tj(
        login_user,
        user_agent,
        'candidatesjob_withdrawn',
        'Candidate Withdrawn',
        "Candidate <a href='/#/talent-pool/#{talent.id}?tab=profile'>#{talent.name}</a>
          has been withdrawn for job <a href='/#/recruiting-job/#{job.id}?tab=pipeline'>#{job.title}</a>
          at stage <b>'#{stage}'</b> for reason <b>#{reason_to_withdrawn}</b>,
          note: <b>#{withdrawn_notes}</b>",
        job.account_manager
      )

      TalentsJobMailer.
        notify_am_candidate_withdrawn_by_recruiter(job.account_manager, self).deliver_now
    end

    def candidate_disqualified(login_user, user_agent, obj)
      create_notificaton_for_tj(
        login_user,
        user_agent,
        'candidatesjob_rejected',
        'Candidate Disqualified',
        "Candidate <a href='/#/talent-pool/#{talent.id}?tab=profile'>#{talent.name}</a>
          has been disqualified for job <a href='/#/recruiting-job/#{job.id}?tab=pipeline'>#{job.title}</a>
          at stage <b>'#{stage}'</b> for reason <b>#{primary_disqualify_reason} - #{secondary_disqualify_reason}</b> , note: #{reason_notes}</b>",
        user
      )

      if login_user.hiring_org_user?
        Message::TalentsJobMessageService.notify_candidate_disqualified(login_user, [job.account_manager, user], self)
      else
        Message::TalentsJobMessageService.notify_candidate_disqualified(login_user, [user], self)
      end
    end

    def candidate_disqualified_by_recruiter(login_user, user_agent, obj)
      create_notificaton_for_tj(
        login_user,
        user_agent,
        'candidatesjob_rejected',
        'Candidate Disqualified',
        "Candidate <a href='/#/talent-pool/#{talent.id}?tab=profile'>#{talent.name}</a>
          has been disqualified for job <a href='/#/recruiting-job/#{job.id}?tab=pipeline'>#{job.title}</a>
          at stage <b>'#{stage}'</b> for reason <b>#{primary_disqualify_reason} - #{secondary_disqualify_reason}</b> ,
          note: #{reason_notes}</b>",
        job.account_manager
      )

      TalentsJobMailer.
        notify_am_candidate_disqualified_by_recruiter(job.account_manager, self).
        deliver_now
    end

    def candidate_reinstated(login_user, user_agent, obj)
      sendable_users = []
      if login_user == user
        sendable_users = [job.account_manager]
      elsif login_user == job.account_manager
        sendable_users = [user]
      else
        sendable_users = [job.account_manager, user]
      end
      sendable_users = sendable_users.uniq

      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        key: 'candidatesjob_reinstated',
        label: 'Candidate Reinstated',
        message: "Candidate <a href='/#/talent-pool/#{talent.id}?tab=profile'>#{talent.name}</a>
          has been reinstate to stage <b>'#{stage}'</b> for job
          <a href='/#/recruiting-job/#{job.id}?tab=pipeline'>#{job.title}</a>
          for reason: <b>#{reinstate_notes}</b>",
        receiver: self,
        from: login_user,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        created_at: Time.now,
        updated_at: Time.now,
      }
      notification = Notification.create(options)
      # pusher notification
      options = notification.attributes
      batch = []
      options[:show_on_timeline] = false
      options.delete('id')

      sendable_users.each do |su|
        o = options.dup
        o['receiver_id'] = su.id
        o['receiver_type'] = 'User'
        o.delete('id')
        batch << o
      end

      if batch.present?
        insert_many = Notification.create(batch)
        insert_many.each { |n| n.send(:pusher_notification) if n.persisted? }
      end

      Message::TalentsJobMessageService.notify_recruiter_candidate_reinstated(sendable_users, self, login_user)
    end

    def create_notificaton_for_tj(current_user, user_agent, key, label, message, user)
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        key: key,
        label: label,
        message: message,
        receiver: self,
        from: current_user,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        created_at: Time.now,
        updated_at: Time.now,
      }
      notification = Notification.create(options)
      # pusher notification
      options = notification.attributes
      batch = []
      options[:show_on_timeline] = false
      options.delete('id')

      o = options.dup
      o['receiver_id'] = user.id
      o['receiver_type'] = 'User'
      o.delete('id')
      batch << o

      if batch.present?
        insert_many = Notification.create(batch)
        insert_many.each { |n| n.send(:pusher_notification) if n.persisted? }
      end
    end

    def send_notification_for_talents_updated_profile(changed_fields, profile_id, user, user_agent, changes = nil)
      profile = Profile.find(profile_id)

      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        key: 'updated_profile',
        label: 'Profile updated',
        message: "#{profile.first_name} #{profile.last_name}
          submitted profile for the #{profile.talents_job.job.title}
          position at #{profile.talents_job.job.client.company_name} was updated.",
        receiver: self,
        from: user,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        created_at: Time.now,
        updated_at: Time.now,
      }
      Notification.create(options)
    end

    def resume_added(user, user_agent, obj)
      resume_notification(
        user,
        user_agent,
        'resume_added',
        'Resume added',
        "A new resume <b>#{obj&.humanize}</b> has been added"
      )
    end

    def resume_updated(user, user_agent, obj)
      resume_notification(
        user,
        user_agent,
        'resume_updated',
        'Resume Updated',
        "Resume <b>#{obj&.humanize}</b> has been set as primary resume"
      )
    end

    def resume_deleted(user, user_agent, obj)
      resume_notification(
        user,
        user_agent,
        'resume_updated',
        'Resume Deleted',
        "A resume has been deleted."
      )
    end

    def resume_notification(user, user_agent, key, label, message)
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        key: key,
        label: label,
        message: message,
        receiver: self,
        from: user,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        created_at: Time.now,
        updated_at: Time.now,
      }
      Notification.create(options)
    end

    def candidate_accepted_offer(user_agent)
      recipients_without_talent = { object: self, from: nil }
      offer_letter_obj = { talents_job: id, offer_letter: offer_letter.try(:id), type: 'Offer' }
      send_notifications(
        recipients_without_talent,
        NotificationEvent.get_event('Candidate moved'),
        {
          job_id: job.id, job_title: job.title,
          team_member: user.first_name,
          talent_id: talent.id, talent_name: talent.name,
          stage: 'Hired',
          note: completed_transitions.where(stage: stage).last&.note,
        },
        'candidatesjob_hired',
        'Candidate Hired',
        user_agent, self,
        offer_letter_obj
      )
      offer_letter.send_notification_for_signing_offer(
        talent, user_agent, nil
      )
      if user&.agency&.invited_for(job)&.incumbent?
        TalentsJobMailer.candidate_accepted_letter_of_offer(user, self).deliver_now
      else
        cc = get_recipients(['recruiter', 'onboarding_agent', 'account_manager'])
        cc << "<hr@crowdstaffing.com>"
        TalentsJobMailer.candidate_accepted_letter_of_offer_non_incumbent(self, cc).deliver_now
      end
      TalentMailer.account_verify_notify(talent).deliver_later unless talent.verified
    end

    def candidate_overview_updated(user, user_agent, obj)
      resume_notification(
        user,
        user_agent,
        'candidate_overview_updated',
        'Candidate Overview Updated',
        "The overview for <b>#{talent.name}</b> has been updated"
      )
    end

    def bill_rate_updated(login_user, user_agent, previous_bill_rate)
      incumbent_ts = user.agency.present? &&
        user.agency.accessibles.incumbents.invited_jobs(job).exists?

      visibility = incumbent_ts ? 'HO_AND_CROWDSTAFFING_AND_TS' : 'HO_AND_CROWDSTAFFING'

      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        key: 'confirmed_bill_rate_updated',
        label: 'Bill Rate Updated',
        message: "The Bill rate for #{profile.first_name} #{profile.last_name} in the <b>
          #{stage}</b> stage on the #{job.title} position has been updated from
          <b>$#{'%.2f' % previous_bill_rate}</b> to
          <b>$#{'%.2f' % rtr.incumbent_bill_rate}</b> with the note: <b>#{rtr.note}</b>",
        receiver: self,
        from: login_user,
        read: true,
        viewed_or_emailed: true,
        visibility: visibility,
        created_at: Time.now,
        updated_at: Time.now,
      }

      notification = Notification.create(options)
      options = notification.attributes
      batch = []
      options[:show_on_timeline] = false
      options[:receiver_type] = 'User'
      options.delete('id')

      if login_user.internal_user? || (login_user.agency_user? && incumbent_ts)
        recipients = if job.hiring_manager.present?
                       [job.hiring_manager]
                     else
                       job.hiring_watchers
                     end

        if job.hiring_manager.present?
          cc = job.hiring_watchers.map { |member| "<#{member.email}>" }.join(', ')
        end

        notify_via_email(
          self,
          login_user,
          { bill_rate: previous_bill_rate, recipients: recipients, cc: cc || [] }
        )
      end

      if login_user.hiring_org_user? || (login_user.agency_user? && incumbent_ts)
        option = options.dup
        option[:receiver_id] = job.supervisor.id
        batch << option
        option = options.dup
        option[:receiver_id] = job.account_manager.id
        batch << option
        cc = "<#{job.supervisor.email}>"

        notify_via_email(
          self,
          login_user,
          { bill_rate: previous_bill_rate, recipients: [job.account_manager], cc: cc || [] }
        )
      end

      if login_user.internal_user?
        recipient = login_user.account_manager? ? job.supervisor : job.account_manager

        if login_user.super_admin? || login_user.admin?
          cc_supervisor = "<#{job.supervisor.email}>"
          option = options.dup
          option[:receiver_id] = job.supervisor.id
          batch << option
        end

        option = options.dup
        option[:receiver_id] = recipient.id
        batch << option

        notify_via_email(
          self,
          login_user,
          { bill_rate: previous_bill_rate, recipients: [recipient], cc: cc_supervisor || [] }
        )
      end

      if incumbent_ts && !login_user.agency_user?
        option = options.dup
        option[:receiver_id] = user.id
        batch << option

        notify_via_email(
          self,
          login_user,
          { bill_rate: previous_bill_rate, recipients: [user], cc: [] }
        )
      end

      if batch.present?
        option = options.dup
        option[:receiver_id] = login_user.id
        batch << option

        insert_many = Notification.create(batch)
        insert_many.each { |n| n.send(:pusher_notification) if n.persisted? }
      end

      notify_via_pusher(self, login_user, incumbent_ts)
    end

    def notify_via_email(talents_job, login_user, options = {})
      if login_user.agency_user?
        Message::TalentsJobMessageService.bill_rate_changes_notify(
          talents_job,
          login_user,
          options[:bill_rate],
          options[:recipients],
          options[:cc]
        )
      else
        options[:recipients].each do |recipient|
          TalentsJobMailer.
            bill_rate_changes_notify(
              talents_job,
              login_user,
              options[:bill_rate],
              recipient,
              options[:cc]
            ).
            deliver_now
        end
      end
    end

    def notify_via_pusher(talents_job, login_user, incumbent_ts)
      if %w(uat production demo).include?(Rails.env)
        job = talents_job.job
        talent = talents_job.talent

        pusher_users = [
          job.account_manager,
          job.hiring_organization.users,
        ].flatten.compact.uniq

        pusher_users << talents_job.user if incumbent_ts

        pusher_users.flatten.compact.uniq.map do |recipient|
          Pusher.trigger(
            "User_#{recipient.id}",
            'bill_rate_notification',
            {
              created_by: login_user.as_json(only: [:id, :first_name, :last_name]),
              talents_job: {
                id: talents_job.id,
                stage: talents_job.stage,
                job: { id: talents_job.job_id },
                talent: talent.as_json(
                  only: [
                    :id, :first_name, :last_name, :email,
                    :city, :state, :state_obj, :country,
                    :country_obj, :postal_code,
                  ],
                ),
              },
            }
          )
        end
      end
    end

    def candidate_stage_changed(login_user, user_agent, stage)
      incumbent_ts = user.agency.present? && user.agency.accessibles.incumbents.invited_jobs(job).exists?
      case stage
      when 'Assignment Begins'
        visibility = incumbent_ts ? 'HO_AND_CROWDSTAFFING_AND_TS' : 'HO_AND_CROWDSTAFFING'
        options = {
          show_on_timeline: false,
          user_agent: user_agent,
          object: self,
          key: 'candidatesjob_assignment_begins',
          label: 'Assignment Begins',
          message: "Candidate #{profile.first_name} #{profile.last_name} has been moved to stage '#{stage}' for job #{job.title} with reason: <b>Assignment Begins<b>",
          receiver: self,
          from: login_user,
          read: true,
          viewed_or_emailed: true,
          visibility: visibility,
          created_at: Time.now,
          updated_at: Time.now,
        }
        options[:receiver_type] = 'User'
        options.delete("id")
        batch = []
        if login_user.internal_user?
          recipients = job.hiring_manager.present? ? [job.hiring_manager] : []
          recipients.push(user) if incumbent_ts
          recipients.each do |recipient|
            o = options.dup
            o[:receiver_id] = recipient.id
            batch << o
            TalentsJobMailer.
              notification_for_stage_changed(self, login_user, recipient).deliver_now
          end
        elsif login_user.hiring_org_user?
          recipients = [job.account_manager]
          recipients.push(user) if incumbent_ts
          recipients.each do |recipient|
            o = options.dup
            o[:receiver_id] = recipient.id
            batch << o
            TalentsJobMailer.
              notification_for_stage_changed(self, login_user, recipient).deliver_now
          end
        end
      end

      if batch.present?
        insert_many = Notification.create(batch)
        insert_many.each { |n| n.send(:pusher_notification) if n.persisted? }
      end
    end

    def timeline_entry_candidate_offer_extension(tag, user)
      options = []
      case tag
      when 'not extended'
        options = {
          show_on_timeline: true,
          object: self,
          receiver: self,
          key: 'candidatesjob_offer_not_extended',
          label: 'Offer',
          message: "Candidate <a href='/#/talent-pool/#{talent_id}?tab=profile'>#{talent.name}</a> has been moved to stage 'Offer' with note: <b>#{hold_offer_reason}</b> by <a href='/#/users/#{user.id}'>#{user.name}</a> ",
          created_at: Time.now,
          updated_at: Time.now,
        }
      when 'offer extended'
        options = {
          show_on_timeline: true,
          object: self,
          receiver: self,
          key: 'candidatesjob_offer_extended',
          label: 'Offer Extended',
          message: "Offer has been extended for the candidate <a href='/#/talent-pool/#{talent_id}?tab=profile'>#{talent.name}</a> by <a href='/#/users/#{user.id}'>#{user.name}</a>",
          created_at: Time.now,
          updated_at: Time.now,
        }
      when 'resend'
        options = {
          show_on_timeline: true,
          object: self,
          receiver: self,
          key: 'candidatesjob_offer_resent',
          label: 'Resent Offer Extension',
          message: "<a href='/#/users/#{user.id}'>#{user.name}</a> has resent the request to send the extended offer for <a href='/#/talent-pool/#{talent_id}?tab=profile'>#{talent.name}</a>",
          created_at: Time.now,
          updated_at: Time.now,
        }
      when 'updated'
        options = {
          show_on_timeline: true,
          object: self,
          receiver: self,
          key: 'candidatesjob_offer_updated',
          label: 'Offer Updated',
          message: "<a href='/#/users/#{user.id}'>#{user.name}</a> has updated the details of the offer to be extended to <a href='/#/talent-pool/#{talent_id}?tab=profile'>#{talent.name}</a>",
          created_at: Time.now,
          updated_at: Time.now,
        }
      when 'cancelled'
        options = {
          show_on_timeline: true,
          object: self,
          receiver: self,
          key: 'candidatesjob_offer_cancelled',
          label: 'Offer Extension Cancelled',
          message: "Candidate <a href='/#/talent-pool/#{talent_id}?tab=profile'>#{talent.name}</a> has had their offer extension cancelled with the reason: <b>#{offer_extension.reason_note}</b> by <a href='/#/users/#{user.id}'>#{user.name}</a>",
          created_at: Time.now,
          updated_at: Time.now,
        }
      when 'revoked'
        options = {
          show_on_timeline: true,
          object: self,
          receiver: self,
          key: 'candidatesjob_offer_revoked',
          label: 'Offer Cancelled',
          message: "Candidate <a href='/#/talent-pool/#{talent_id}?tab=profile'>#{talent.name}</a> has had their offer cancelled with the reason: Disqualified, #{primary_disqualify_reason} - #{secondary_disqualify_reason}. by <a href='/#/users/#{user.id}'>#{user.name}</a>",
          created_at: Time.now,
          updated_at: Time.now,
        }
      when 'sent'
        options = {
          show_on_timeline: true,
          object: self,
          receiver: self,
          key: 'candidatesjob_offer_sent',
          label: 'Offer Sent',
          message: "Candidate <a href='/#/talent-pool/#{talent_id}?tab=profile'>#{talent.name}" \
            "</a> has been sent a " \
            "<span class='download text-blue'>Letter of Offer</span>" \
            " by <a href='/#/users/#{user.id}'>#{user.name}</a>",
          created_at: Time.now,
          updated_at: Time.now,
          specific_obj: { offer_letter_id: offer_letter.id },
        }

      when 'letter resent'
        options = {
          show_on_timeline: true,
          object: self,
          receiver: self,
          key: 'candidatesjob_offer_letter_resent',
          label: 'Offer Resent',
          message: "<a href='/#/users/#{user.id}'>#{user.name}</a> has resent the letter of offer to <a href='/#/talent-pool/#{talent_id}?tab=profile'>#{talent.name}</a>",
          created_at: Time.now,
          updated_at: Time.now,
        }

      when 'internal offer revoked'
        options = {
          show_on_timeline: true,
          object: self,
          receiver: self,
          key: 'candidatesjob_offer_letter_revoked',
          label: 'Offer Cancelled',
          message: "Candidate <a href='/#/talent-pool/#{talent_id}?tab=profile'>#{talent.name}</a> has had their offer revoked with the reason: Disqualified, #{primary_disqualify_reason}. #{secondary_disqualify_reason}. by <a href='/#/users/#{user.id}'>#{user.name}</a>",
          created_at: Time.now,
          updated_at: Time.now,
        }

      when 'offer letter cancelled'
        options = {
          show_on_timeline: true,
          object: self,
          receiver: self,
          key: 'candidatesjob_offer_cancelled',
          label: 'Offer Cancelled',
          message: "Candidate <a href='/#/talent-pool/#{talent_id}?tab=profile'>#{talent.name}</a> has had their offer cancelled with the reason: <b>#{offer_letter.reason_note}</b> by <a href='/#/users/#{user.id}'>#{user.name}</a>",
          created_at: Time.now,
          updated_at: Time.now,
        }
      end

      Notification.create(options) if options
    end

    def offer_extension_notifications(status, collaborators, logged_user, options = {})
      bill_rate_change = Set['incumbent_bill_rate', 'incumbent_bill_period', 'updated_at', 'subject']
      incumbent = user&.agency&.invited_for(job)&.incumbent?
      watchers = job.hiring_watchers
      hm = job.hiring_manager
      cc = []

      case status
      when 'ho_offer_not_extended'
        timeline_entry_candidate_offer_extension('not extended', logged_user)

        TalentsJobMailer.offer_letter_hold_extension(
          self,
          get_recipients(['supervisor', 'onboarding_agent']),
          job.account_manager,
          logged_user,
          nil
        ).deliver_now

        TalentsJobMailer.offer_letter_hold_extension(
          self,
          get_recipients(['talent_supplier', 'ts_admin']),
          user,
          logged_user,
          nil
        ).deliver_now

        if collaborators
          watchers.each do |watcher|
            TalentsJobMailer.notify_ho_collaborators_offer_not_extended(
              self,
              watcher,
              logged_user
            ).deliver_now
          end

          if hm && (hm != logged_user)
            TalentsJobMailer.notify_ho_collaborators_offer_not_extended(
              self,
              hm,
              logged_user
            ).deliver_now
          end
        end

      when 'ho_offer_extended'
        timeline_entry_candidate_offer_extension('offer extended', logged_user)

        Message::TalentsJobMessageService.notify_am_offer_letter(
          self,
          collaborators ? get_cc : [],
          get_bcc,
          logged_user
        )

        Message::TalentsJobMessageService.notify_candidate_offer_extended(self)

      when 'ho_offer_updated'
        timeline_entry_candidate_offer_extension('updated', logged_user)

        cc = get_recipients(['ho_collab', 'hiring_manager']) if offer_extension&.notify_collaborators

        changes = options[:changed_fields].to_set.subset?(bill_rate_change)

        if changes && incumbent
          TalentsJobMailer.notify_offer_extension_updated(
            self,
            options[:changed_fields],
            user,
            cc,
            offer_extension
          ).deliver_now
        elsif !changes
          TalentsJobMailer.notify_offer_extension_updated(
            self,
            options[:changed_fields],
            user,
            cc,
            offer_extension
          ).deliver_now
        end

        Message::TalentsJobMessageService.notify_offer_extension_updated(
          self,
          options[:changed_fields],
          job.account_manager,
          get_bcc,
          offer_extension&.notify_collaborators ? get_cc : [],
          offer_extension
        )
      when 'ho_offer_resent'
        timeline_entry_candidate_offer_extension('resend', logged_user)

        Message::TalentsJobMessageService.notify_am_offer_letter(
          self,
          collaborators ? get_cc : [],
          get_bcc,
          logged_user
        )

      when 'ho_offer_cancel'
        timeline_entry_candidate_offer_extension('cancelled', logged_user)

        if collaborators
          watchers.each do |watcher|
            TalentsJobMailer.notify_ho_collaborators_offer_extension_cancelled(
              self,
              watcher,
              offer_extension,
              "FYI: Offer Extension cancelled from #{talent.name}"
            ).deliver_now
          end

          if hm && (hm != logged_user)
            TalentsJobMailer.notify_ho_collaborators_offer_extension_cancelled(
              self,
              hm,
              offer_extension,
              "FYI: Offer Extension cancelled from #{talent.name}"
            ).deliver_now
          end
        end

        TalentsJobMailer.notify_offer_extension_cancelled(
          self,
          get_recipients(['supervisor', 'recruiter']),
          'Urgent: offer extension has been cancelled',
          offer_extension
        ).deliver_now

      when 'ho_offer_revoked'
        timeline_entry_candidate_offer_extension('revoked', logged_user)

        watchers.each do |watcher|
          TalentsJobMailer.notify_collaborator_offer_extension_revoked(
            self,
            watcher,
            "FYI: Extended offer cancelled from #{talent.name}"
          ).deliver_now
        end

        if hm && (hm != logged_user)
          TalentsJobMailer.notify_collaborator_offer_extension_revoked(
            self,
            hm,
            "FYI: Extended offer cancelled from #{talent.name}"
          ).deliver_now
        end

        TalentsJobMailer.notify_am_offer_extension_revoked(
          self,
          get_recipients(['supervisor', 'recruiter'])
        ).deliver_now

      when 'internal_offer_stage'
        timeline_entry_candidate_offer_extension('not extended', logged_user)

        if job.supervisor.present?
          TalentsJobMailer.offer_letter_hold_extension(
            self,
            get_recipients(['onboarding_agent', 'account_manager']),
            nil,
            logged_user,
            true
          ).deliver_now
        end

        if options[:ts]
          TalentsJobMailer.offer_letter_hold_extension(
            self,
            get_recipients(['talent_supplier', 'ts_admin']),
            user,
            logged_user,
            nil
          ).deliver_now
        end

        if job.hiring_manager.present? && options[:hm]
          TalentsJobMailer.notify_ho_collaborators_offer_not_extended(
            self,
            job.hiring_manager,
            logged_user
          ).deliver_now
        end

        if collaborators
          watchers.each do |watcher|
            TalentsJobMailer.notify_ho_collaborators_offer_not_extended(
              self,
              watcher,
              logged_user
            ).deliver_now
          end
        end

      when 'internal_offer_letter_sent'
        send_candidate_offer_letter(incumbent)

        timeline_entry_candidate_offer_extension('sent', logged_user)

      when 'internal_offer_resent'
        send_candidate_offer_letter(incumbent)

        timeline_entry_candidate_offer_extension('letter resent', logged_user)

      when 'internal_offer_cancelled'
        timeline_entry_candidate_offer_extension('offer letter cancelled', logged_user)

        if collaborators
          watchers.each do |watcher|
            TalentsJobMailer.notify_ho_collaborators_offer_extension_cancelled(
              self,
              watcher,
              offer_letter,
              "FYI: Offer cancelled from #{talent.name}"
            ).deliver_now
          end

          if hm && (hm != logged_user)
            TalentsJobMailer.notify_ho_collaborators_offer_extension_cancelled(
              self,
              hm,
              offer_letter,
              "FYI: Offer cancelled from #{talent.name}"
            ).deliver_now
          end
        end

        TalentsJobMailer.notify_offer_extension_cancelled(
          self,
          get_recipients(['supervisor', 'recruiter']),
          "Urgent: offer has been rescinded",
          offer_letter
        ).deliver_now

      when 'internal_offer_updated'
        cc = get_recipients(['ho_collab', 'hiring_manager']) if offer_letter&.notify_collaborators

        changes = options[:changed_fields].to_set.subset?(bill_rate_change)
        if changes && incumbent
          TalentsJobMailer.notify_offer_letter_updated(
            self,
            options[:changed_fields],
            user,
            cc,
            offer_letter
          ).deliver_now
        elsif !changes
          TalentsJobMailer.notify_offer_letter_updated(
            self,
            options[:changed_fields],
            user,
            cc,
            offer_letter
          ).deliver_now
        end

        Message::TalentsJobMessageService.notify_offer_letter_updated(
          self,
          options[:changed_fields],
          job.account_manager,
          get_bcc,
          offer_letter&.notify_collaborators ? get_cc : [],
          offer_letter
        )

        self.timeline_entry_candidate_offer_extension('updated', logged_user)

      when 'internal_offer_revoked'
        timeline_entry_candidate_offer_extension('internal offer revoked', logged_user)

        watchers.each do |watcher|
          TalentsJobMailer.notify_collaborator_offer_extension_revoked(
            self,
            watcher,
            "FYI: Offer revoked from #{talent.name.titleize}"
          ).deliver_now
        end

        if hm && (hm != logged_user)
          TalentsJobMailer.notify_collaborator_offer_extension_revoked(
            self,
            hm,
            "FYI: Offer revoked from #{talent.name.titleize}"
          ).deliver_now
        end

        TalentsJobMailer.notify_am_offer_letter_revoked(
          self,
          get_recipients(['supervisor', 'recruiter'])
        ).deliver_now
      end
    end

    def send_candidate_offer_letter(incumbent)
      if incumbent
        Message::TalentsJobMessageService.notify_candidate_offer_letter(self)
      else
        Message::TalentsJobMessageService.notify_candidate_offer_letter_non_incumbent(self)
      end
    end


    def get_cc
      cc = []
      cc << job.hiring_watchers if job.hiring_watchers
      cc << job.hiring_manager if job.hiring_manager && (job.hiring_manager != current_user)
      cc.flatten.compact.uniq
    end

    def get_bcc
      bcc = [job.supervisor]
      bcc << job.onboarding_agent if job.type_of_job.eql?('Contract') && !user&.agency&.invited_for(job)&.incumbent?

      bcc
    end

    def get_recipients(recipients)
      cc = []
      current_user = LoggedinUser.current_user

      if recipients.include?('ho_collab')
        if job.hiring_watchers
          cc << job.hiring_watchers.map { |member| "<#{member.email}>" }.join(', ')
        end
      end

      if recipients.include?('hiring_manager') && job.hiring_manager &&
        (job.hiring_manager != current_user)
        cc << "<#{job.hiring_manager.email}>"
      end

      if recipients.include?('supervisor') && job.supervisor
        cc << "<#{job.supervisor.email}>"
      end

      incumbent = user&.agency&.invited_for(job)&.incumbent?
      if recipients.include?('onboarding_agent') && job.type_of_job.eql?('Contract') && !incumbent
        cc << "<#{job.onboarding_agent.email}>" if job.onboarding_agent
      end

      if recipients.include?('talent_supplier') && user.agency_user?
        user.agency.users.where(primary_role: ['agency admin', 'agency owner']).each do |user|
          cc << "<#{user.email}>" if user.enable
        end
      end

      if recipients.include?('ts_admin') && user.teams.present?
        User.get_team_admin(user).each do |admin|
          cc << "<#{admin.email}>" if admin != current_user
        end
      end

      if recipients.include?('recruiter') && user
        cc << "<#{user.email}>"
      end

      if recipients.include?('account_manager')
        cc << "<#{job.account_manager.email}>"
      end

      cc
    end

    def assignment_update_request(user, user_agent, obj)
      options = {
        show_on_timeline: true,
        object: self,
        key: 'assignment_update_request',
        label: 'Assignment Update Request Created',
        message: "#{user.name} has sent an update request to
                  #{job.account_manager.name} to update
                  #{talent.full_name} assignment details.",
        receiver: self,
        from: user,
        created_at: Time.now,
        updated_at: Time.now,
      }
      notification = Notification.create(options)

      # pusher notification
      options = notification.attributes
      batch = []
      options[:show_on_timeline] = false
      options[:message] = message
      options.delete('id')
      users = job.account_manager.account_manager_admins +
              [job.supervisor] + [job.onboarding_agent]

      users.flatten.uniq.compact.each do |u|
        o = options.dup
        o['receiver_id'] = u.id
        o['receiver_type'] = 'User'
        batch << o
        o.delete('id')
      end

      if batch.present?
        insert_many = Notification.create(batch)
        insert_many.map do |notification_obj|
          notification_obj.send(:pusher_notification) if notification_obj.persisted?
        end
      end
    end
  end
end
