module Notifiable
  module NotifiableJob
    attr_accessor :edited_by

    def send_destroy_notification_for_job(user, user_agent)
      self.edited_by = user
      send_notifications(
        default_recipient_job,
        NotificationEvent.get_event('Job Delete'),
        { job_title: title },
        'job_destroy',
        'Job Deleted',
        user_agent,
        self
      )
    end

    def send_destroy_notification_for_jobs_recruitment_pipeline(pipeline, user, user_agent)
      self.edited_by = user
      send_notifications(
        default_recipient_job,
        NotificationEvent.get_event('Recruitment Pipeline Deleted'),
        {
          pipeline: pipeline,
          obj_name: title,
          link: "/#/job-marketplace/#{id}?tab=pipeline",
        },
        'job_recruitment_pipeline_destroy',
        'Recruitment Pipeline Deleted',
        user_agent,
        self
      )
    end

    def send_notification_for_new_children_for_job(obj, user, user_agent, changes = nil)
      self.edited_by = user
      job = self
      send_notifications(
        { object: self, from: created_by },
        NotificationEvent.get_event('Children Created for job'),
        {
          obj: obj,
          job_title: job.title,
          job_id: job.id,
          updated_by: user.is_a?(User) ? "by " + user.first_name : '',
        },
        "job_#{obj.downcase.split('-').shift.split(' ').join('_')}_created",
        "Job's #{obj.downcase.split('-').shift.split(' ').join(' ')} created",
        user_agent,
        self
      )
    end

    def send_notification_for_job(changed_fields, user, user_agent, changes = nil)
      self.edited_by = user
      recipient = default_recipient_job

      if changed_fields.include?(self.class.human_attribute_name('stage'))
        case stage
        when 'Draft'
          if !beeline?
            event_name = 'Job Created'
            recipient = { object: self, from: created_by }
          end
        when 'Open'
          if changed_fields.include?('Is private') &&
            !is_private &&
            !beeline? &&
            billing_term.is_exclusive.is_false?

            picked_by.uniq.simplify.each { |u| JobsMailer.notify_job_published(u, self).deliver_now }
          end
        end

        reason = reason_to_close_job == 'Other' ? closed_note : reason_to_close_job

        if event_name
          send_notifications(
            recipient,
            NotificationEvent.get_event(event_name),
            {
              job_id: id.to_s,
              job_title: title,
              client_name: client.company_name,
              client_id: client_id,
              reason_to_close_job: reason,
              reason_to_reopen: reason_to_reopen,
            },
            "job_" + event_name.split(' ')[-1].downcase,
            event_name,
            user_agent,
            self
          )
        end

        if stage.eql?('Scheduled') && published_at.present?
          if changed_fields.include?('Is private')
            notify_job_schedule(edited_by, user_agent, changes['is_private'][0])
          else
            notify_job_schedule(edited_by, user_agent, false)
          end
        end

      elsif changed_fields.include?('Id') &&
            changes["id"][0].nil? &&
            !changes["id"][1].nil? &&
            stage.eql?('Draft') &&
            !beeline?
        recipient = { object: self, from: created_by }
        send_notifications(
          recipient,
          NotificationEvent.get_event('Job Created'),
          {
            job_id: id.to_s,
            job_title: title,
            client_name: client.company_name,
            client_id: client_id,
          },
          'job_created',
          'Job Created',
          user_agent,
          self
        )
      elsif (updated_at - created_at) < 60
        nil
      elsif changed_fields.include?(self.class.human_attribute_name('locked_at'))
        label = enable ? 'Job Enabled' : 'Job Disabled'
        send_notifications(
          recipient,
          NotificationEvent.get_event(label),
          { job_id: id, job_title: title, stage: stage },
          "job_" + label.split(' ')[-1].downcase,
          label,
          user_agent,
          self
        )
      elsif changed_fields.include?(self.class.human_attribute_name(:msp_vms_fee_rate))
        send_notifications(
          { object: self },
          NotificationEvent.get_event('VMS updated'),
          {
            client_id: client.id,
            client_name: client.company_name,
            date: Date.today.strftime('%d/%m/%Y'),
            time: Time.now.strftime("%I:%M %p"),
          },
          'job_updated',
          'Job Billing Updated',
          user_agent,
          self
        )
      elsif changed_fields.include?('Account manager')
        send_notifications(
          recipient,
          NotificationEvent.get_event('Job Updated'),
          {
            job_id: id,
            fields: "Account manager - #{account_manager ? account_manager.username : 'none'}",
            job_title: title,
          },
          'job_updated',
          'Job Updated',
          user_agent,
          self
        )
      elsif changed_fields.include?('onboarding agent')
        send_notifications(
          recipient,
          NotificationEvent.get_event('Job Updated'),
          {
            job_id: id,
            fields: "onboarding agent - #{onboarding_agent ? onboarding_agent.username : 'none'}",
            job_title: title,
          },
          'job_updated',
          'Job Updated',
          user_agent,
          self
        )
      elsif changed_fields.include?('Supervisor')
        send_notifications(
          recipient,
          NotificationEvent.get_event('Job Updated'),
          {
            job_id: id,
            fields: "Supervisor - #{supervisor ? supervisor.username : 'none'}",
            job_title: title,
          },
          'job_updated',
          'Job Updated',
          user_agent,
          self
        )
      elsif (changed_fields & ['Published at']).any? && published_at.present?
        private_param = changed_fields.include?('Is private') ? changes["is_private"][0] : false
        notify_job_schedule(edited_by, user_agent, private_param)
      elsif changed_fields.include?('Is private') &&
        changes["is_private"][0].eql?(true) &&
        is_private.eql?(false) &&
        published_at.present? &&
        published? &&
        !beeline?

        event_name = 'Tap into the Crowd'
        send_notifications(
          recipient,
          NotificationEvent.get_event(event_name),
          {
            job_id: id,
            job_title: title,
            client_name: client.company_name,
            client_id: client_id,
          },
          "job_" + event_name.split(' ')[-1].downcase,
          event_name,
          user_agent,
          self
        )
      elsif changed_fields.include?('Is private') &&
        changes["is_private"][0].eql?(false) &&
        is_private.eql?(true) &&
        published_at.present? &&
        published?

        event_name = 'Job Private'
        send_notifications(
          recipient,
          NotificationEvent.get_event(event_name),
          {
            job_id: id,
            job_title: title,
          },
          "job_" + event_name.split(' ')[-1].downcase,
          event_name,
          user_agent,
          self
        )
      else
        changed = changed_fields &
          (
            [
              "title", "address", "city", "state", "postal_code",
              "country", "start_date", "end_date", "summary", "salary",
              "pay_period", "currency", "remote", "minimum qualification",
              "years_of_experience", "preferred_qualification",
              "responsibilities", "additional_detail", "position", "duration",
              "public", "work_permits", "certifications", "location_type",
              "duration_period", "bill_rate", "agency_commission",
              "placement_commission", "Category", "Incumbent bill rate",
            ].
              collect { |x| self.class.human_attribute_name(x) }
          )
        changed += changed_fields.
          select { |x| x.match(/Recruitment pipeline|Hiring Pipeline|Onboarding Package/) }
        changed += changed_fields.
          select { |f| ["Skill ids"].include?(f) }.
          collect { |f| f.split(' id').first.pluralize }
        return if changed.blank?
        if user.hiring_org_user?
          notifiable_users.each do |notify|
            job_updated(user_agent, self, changed, recipient.merge(to: notify))
          end
        else
          job_updated(user_agent, self, changed, recipient)
        end
      end
    end

    def job_updated(user_agent, job, fields, notifiers)
      send_notifications(
        notifiers,
        NotificationEvent.get_event('Job Updated'),
        {
          job_id: job.id,
          fields: fields.join(', '),
          job_title: job.title,
        },
        'job_updated',
        'Job Updated',
        user_agent,
        job
      )
    end

    def notify_job_schedule(edited_by, user_agent, is_private_was)
      job_published = published_at > Time.now
      event_name = job_published ? 'Job Scheduled' : 'Job Published'
      label = job_published ? 'job_scheduled' : 'job_published'
      time_zone = timezone.presence || client.timezone.presence
      published_date = time_zone.
        get_dst_time(published_at.to_time).
        to_s(:long).concat(' ').
        concat(time_zone[:abbr])

      send_notifications(
        { object: self, from: edited_by },
        NotificationEvent.get_event(event_name),
        {
          job_id: id,
          job_title: title,
          client_name: client.company_name,
          client_id: client_id,
          published_at: published_date,
        },
        label,
        event_name,
        user_agent,
        self
      )
    end

    def assign_recruiter_notification(user_ids = [], edited_by, user_agent)
      return if user_ids.blank?
      users = User.where("id in (?)", user_ids).compact.uniq
      recipients = default_recipient_job
      label = 'Assigned Recruiter'
      users.each do |user|
        variables = {
          users_link: "team-members",
          user_name: user.name, user_id: user.id,
          job_id: id,
          job_title: title,
        }
        recipients[:object] = self
        send_notifications(
          recipients,
          NotificationEvent.get_event(label),
          variables,
          "assigned_recruiters",
          label,
          user_agent,
          edited_by
        )
        JobsMailer.assign_recruiter_notify(self, user).deliver_now
      end
    end

    ######################## new notification system ########################
    def job_close(user, user_agent, obj)
      reason = reason_to_close_job == 'Other' ? closed_note : reason_to_close_job
      prev_status = obj[:is_onhold].is_true? ? 'On Hold' : obj[:stage]

      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        key: 'job_closed',
        label: 'Job Closed',
        message: "Job status was changed from #{prev_status} to closed for reason: #{reason}",
        receiver: self,
        from: user,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        created_at: Time.now,
        updated_at: Time.now,
      }
      notification = Notification.create(options)

      if notification_to_suppliers_on_close.is_true?
        users = notifiable_users
      else
        users = notifiable_users.where.not(role_group: 2)
      end

      options = notification.attributes
      batch = []
      options[:show_on_timeline] = false
      options[:message] = "Job <a href='/#/job-marketplace/#{id}'>#{title}</a> is closed because #{reason}"
      options.delete('id')

      notifiable_users.compact.each do |u|
        o = options.dup
        o['receiver_id'] = u.id
        o['receiver_type'] = 'User'
        batch << o
        o.delete('id')
      end

      if batch.present?
        insert_many = Notification.create(batch)
        insert_many.each { |n| n.send(:pusher_notification) if n.persisted? }
      end

      notifiable_users.each do |notify|
        JobsMailer.notify_job_close(notify, self).deliver_later
      end

      if notification_to_candidates_on_close.is_true?
        stages = ['Signed', 'Submitted', 'Applied', 'Offer'].
          concat(PipelineStep::DYNAMIC_STAGE_TYPES)

        user_talent_hash = {}
        talents_jobs.not_rejected.not_withdrawn.where(stage: stages).each do |talents_job|
          user_talent_hash[talents_job.user] = talents_job.talent
        end
        Message::JobMessageService.notify_candidate_job_close(user_talent_hash, self)
      end
    end

    def job_onhold(user, user_agent, obj)
      create_notificaton(
        user,
        user_agent,
        'job_onhold',
        'Job On-Hold',
        "Job status was changed from #{obj[:stage]} to on hold for reason: #{reason_to_onhold_job}",
        "Job <a href='/#/job-marketplace/#{id}'>#{title}</a> is put on hold because
          #{reason_to_onhold_job}",
        notifiable_users,
        self
      )

      notifiable_users.each { |notify| JobsMailer.notify_job_hold(notify, self).deliver_later }
    end

    def job_autohold(user, user_agent, obj)
      create_notificaton(
        user,
        user_agent,
        'job_onhold',
        'Job On-Hold',
        'This job is on hold because the applied candidates profiles are being screened by the hiring manager',
        "Job <a href='/#/job-marketplace/#{id}'>#{title}</a> is put on hold because the applied candidates profiles are being screened by the hiring manager",
        notifiable_users,
        self
      )

      notifiable_users.each { |notify| JobsMailer.notify_job_autohold(notify, self).deliver_later }
    end

    def job_unhold(user, user_agent, obj)
      text = "Job status was changed from on hold to #{stage} for reason: #{reason_to_unhold_job}"
      if reason_to_onhold_job.eql?(Job::HOLD_UNHOLD_REASON[:AUTO_HOLD_REASON])
        text += " by Crowdstaffing"
      end
      create_notificaton(
        user,
        user_agent,
        'job_unhold',
        'Job Resumed',
        text,
        "Job <a href='/#/job-marketplace/#{id}'>#{title}</a> is now accepting applicants",
        notifiable_users,
        self
      )

      notifiable_users.each { |notify| JobsMailer.notify_job_unhold(notify, self).deliver_later }
    end

    def job_reopen(user, user_agent, obj)
      create_notificaton(
        user,
        user_agent,
        'job_reopened',
        'Job Reopened',
        "Job status was changed from #{obj[:stage]} to #{stage} for reason: #{reason_to_reopen}",
        "Job <a href='/#/job-marketplace/#{id}'>#{title}</a> is reopened and enabled now
          because #{reason_to_reopen}",
        notifiable_users,
        self
      )

      ReopenJob.set(wait_until: Time.now + 15.minutes).perform_later(self)
    end

    def job_published(user, user_agent, obj)
      return if beeline? || !published?
      user_ids = SavedClientsUser.
        left_outer_joins(user: :agency).
        distinct.
        where(agencies: { restrict_access: false }, client_id: client_id).
        pluck(:user_id).
        uniq

      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        key: 'job_published',
        label: 'Job Published',
        message: 'Job has been published and is enabled now',
        receiver: self,
        from: user,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        created_at: Time.now,
        updated_at: Time.now,
      }

      notification = Notification.create(options)
      # pusher notification
      return if is_private || billing_term.is_exclusive.is_true?
      options = notification.attributes.except(:show_on_timeline, :message)
      batch = []
      options["show_on_timeline"] = false
      options["message"] = "Job <a href='/#/job-marketplace/#{id}'>#{title}</a> has been published and is enabled now"
      options.delete('id')

      user_ids.compact.each do |user_id|
        o = options.dup
        o['receiver_id'] = user_id
        o['receiver_type'] = 'User'
        batch << o
        o.delete('id')
      end

      if batch.present?
        insert_many = Notification.where(id: Notification.bulk_import(batch).ids)
        insert_many.each { |n| n.send(:pusher_notification) }
      end

      user_ids.each do |user_id|
        notify = User.find(user_id)
        JobsMailer.notify_job_published(notify, self).deliver_now if notify
      end

      User.find_limited_users(self).each do |notify|
        if notify
          JobsMailer.job_published_notify(notify, self, { type: 'AccessibleJob' }).deliver_now
        end
      end
    end

    def job_opportunity(user, user_agent, notifiable)
      users = User.where(id: notifiable)
      create_notificaton(
        user,
        user_agent,
        'job_opportunity',
        'New job opportunities',
        'New job opportunities recommendations',
        "Job <a href='/#/job-marketplace/#{id}'>#{title}</a> has been recommended to you based on your expertise.",
        users,
        self
      )

      Message::JobMessageService.notify_job_opportunity(users, self, user)
    end

    def job_clicked(user, user_agent, _obj)
      users = [account_manager, supervisor, user]
      users << user.agency.owner if user.team_admin? || user.team_member?
      create_notificaton(
        user,
        user_agent,
        'job_clicked',
        'New job opportunity saved',
        'New job from opportunity has been saved',
        "New job opportunity <a href='/#/recruiting-job/#{id}'>#{title}</a> has been saved from recommendations",
        users,
        self
      )
    end

    def job_dismissed(user, user_agent, _obj)
      reason = distributions.dismissed_by(user).last&.dismissed_reason
      reason = "due to ".concat(reason) if reason.present?
      users = [account_manager, supervisor, user]
      users << user.agency.owner if user.team_admin? || user.team_member?
      create_notificaton(
        user,
        user_agent,
        'job_dismissed',
        'New job opportunity dismissed',
        "New job from opportunity has been dismissed #{reason}",
        "New job opportunity <a href='/#/job-marketplace/#{id}'>#{title}</a> has been dismissed from recommendations #{reason}",
        users,
        self
      )
    end

    def job_saved(user, user_agent, obj)
      job_save_unsave(user, user_agent, obj, 'job_saved', 'Job Saved')
    end

    def job_unsaved(user, user_agent, obj)
      job_save_unsave(user, user_agent, obj, 'job_unsaved', 'Job Unsaved')
    end

    def job_save_unsave(user, user_agent, obj, key, message)
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        key: key,
        label: message,
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

    def create_notificaton(current_user, user_agent, key, label, timeline_message, message, users, job)
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: job,
        key: key,
        label: label,
        message: timeline_message,
        receiver: job,
        from: current_user,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
        created_at: Time.now,
        updated_at: Time.now,
      }
      notification = Notification.create(options)
      # pusher notification
      unless key.eql?('job_published')
        options = notification.attributes
        batch = []
        options[:show_on_timeline] = false
        options[:message] = message
        options.delete('id')

        users.compact.each do |u|
          o = options.dup
          o['receiver_id'] = u.id
          o['receiver_type'] = 'User'
          batch << o
          o.delete('id')
        end

        if batch.present?
          insert_many = Notification.create(batch)
          insert_many.each { |n| n.send(:pusher_notification) if n.persisted? }
        end
      end
    end

    def send_notification_for_jobs_note(changed_fields, note_id, user, user_agent, changes=nil)
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
          message: "Comment '#{note.note}' edited for <a href='/#/recruiting-job/#{id}'>#{title}</a> position at <a href='/#/clients/#{client_id}'>#{client.company_name}</a>",
        })
      elsif note.parent
        options.merge!({
          key: "comment_created",
          label: "Replied to comment",
          message: "Reply on comment '#{note.note}' for <a href='/#/recruiting-job/#{id}}'>#{title}</a> position at <a href='/#/clients/#{client_id}'>#{client.company_name}</a> has been added."
        })
      else
        options.merge!({
          key: "comment_created",
          label: "Comment Created",
          message: "Comment '#{note.note}' added to <a href='/#/recruiting-job/#{id}}'>#{title}</a> position at <a href='/#/clients/#{client_id}'>#{client.company_name}</a>",
        })
      end
      notification = Notification.create(options)
      # pusher notification
      options = notification.attributes
      batch = []
      options[:show_on_timeline] = false
      if note.announcement.is_true?
        options[:message] = "There is an announcement: '#{note.note}' added to <a href='/#/recruiting-job/#{id}}'>#{title}</a> position at #{client.company_name}"
      else
        options[:message] = "You have been mentioned in a comment: '#{note.note}' added to <a href='/#/recruiting-job/#{id}}'>#{title}</a> position at #{client.company_name}"
      end
      options.delete("id")
      note.mentioned.each do |u|
        o = options.dup
        o['receiver_id'] = u.id
        o['receiver_type'] = 'User'
        o.delete('id')
        batch << o
      end
      if batch.present?
        insert_many = Notification.create(batch)
        insert_many.each { |n| n.send(:pusher_notification) if n.persisted? }
      end
    end

    def send_destroy_notification_for_jobs_note(note, visibility, user, user_agent)
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
        message: "Comment '#{note}' deleted for <a href='/#/recruiting-job/#{id}}'>#{title}</a> position at #{client.company_name}",
      })
      Notification.create(options)
    end

    def hiring_manager_assigned(user, user_agent, old_hiring_manager)
      return if hiring_manager_id.eql?(old_hiring_manager&.id)
      message = old_hiring_manager.present? ?
        "Hiring manager changed from #{old_hiring_manager.name} to #{hiring_manager.name}" :
        "Hiring manager #{hiring_manager.name} assigned"

      create_notificaton(
        user,
        user_agent,
        'job_ho_manager_assigned',
        'Job Hiring manager assigned',
        "Job #{message}",
        "Job <a href='/#/job-marketplace/#{id}'>#{title}</a>, #{job_id} #{message}",
        notifiable_users,
        self
      )
    end

    def hiring_users_assigned(user, user_agent, old_watcher_ids)
      collaborators = hiring_watchers.where.not(id: old_watcher_ids)
      return unless collaborators.exists?
      message = "#{collaborators.map(&:name).join(', ')} has been added to the hiring team"

      create_notificaton(
        user,
        user_agent,
        'job_ho_users_assigned',
        'Job Hiring Collaborator assigned',
        "Job collaborator #{message}",
        "Job <a href='/#/job-marketplace/#{id}'>#{title}</a>, #{job_id} #{message}",
        notifiable_users,
        self
      )
    end
  end
end
