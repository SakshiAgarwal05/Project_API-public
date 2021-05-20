module Notifiable
  module NotifiableClient
    attr_accessor :edited_by

    def send_destroy_notification_for_client(user, user_agent)
      self.edited_by = user
      send_notifications(
        default_recipient_client,
        NotificationEvent.get_event('Client Deleted'),
        { client_name: company_name },
        'client_deleted',
        'Client Deleted',
        user_agent,
        self
      )
    end

    def send_destroy_notification_for_clients_contact(contact, user, user_agent)
      self.edited_by = user
      send_notifications(
        default_recipient_client,
        NotificationEvent.get_event('Contact Deleted'),
        {
          contact: contact,
          contactable_name: company_name,
          link: "/#/clients/#{id}?tab=contacts",
        },
        'client_contact_destroy',
        'Contact Deleted',
        user_agent,
        self
      )
    end

    def send_destroy_notification_for_clients_recruitment_pipeline(pipeline, user, user_agent)
      self.edited_by = user
      send_notifications(
        default_recipient_client,
        NotificationEvent.get_event('Recruitment Pipeline Deleted'),
        {
          pipeline: pipeline,
          obj_name: company_name,
          link: "/#/clients/#{id}?tab=pipeline",
        },
        'client_recruitment_pipeline_destroy',
        'Recruitment Pipeline Deleted',
        user_agent,
        self
      )
    end

    def send_destroy_notification_for_clients_medium(medium, user, user_agent)
      self.edited_by = user
      send_notifications(
        default_recipient_client,
        NotificationEvent.get_event('Medium Deleted'),
        { medium: medium, obj_name: company_name, link: "/#/clients/#{id}" },
        'medium_destroy',
        'Medium Deleted',
        user_agent,
        self
      )
    end

    def send_notification_for_clients_note(changed_fields, note, user, user_agent, changes = nil)
      self.edited_by = user
      send_notifications(
        default_recipient_client,
        NotificationEvent.get_event('Note Created'),
        {
          user_name: user.first_name,
          notable_name: company_name,
          notable_link: "/#/clients/#{id}?tab=notes",
          note: note,
        },
        'note_created',
        'Note Created',
        user_agent,
        self
      )
    end

    def send_notification_for_new_children_for_client(obj, user, user_agent, changes = nil)
      self.edited_by = user
      client = self
      send_notifications(
        { object: self, from: created_by },
        NotificationEvent.get_event('Children Created for client'),
        {
          obj: obj,
          client_name: client.company_name,
          client_id: client.id,
          updated_by: user.is_a?(User) ? "by " + user.first_name : '',
        },
        "client_#{obj.downcase.split('-').shift.split(' ').join('_')}_created",
        "Client's #{obj.downcase.split('-').shift.split(' ').join(' ')} created",
        user_agent,
        self
      )
    end

    def get_object_to_notify
      return self if is_a?(Client)
      return contactable if is_a?(Contact)
      return embeddable if is_a?(RecruitmentPipeline) || is_a?(OnboardingPackage)
      return mediable if is_a?(Medium)
    end

    def send_notification_for_client(changed_fields, user, user_agent, changes = nil)
      self.edited_by = user
      obj = get_object_to_notify
      if changed_fields.include?(self.class.human_attribute_name("active"))
        label = (active? ? 'Client Enabled' : 'Client Disabled')
        send_notifications(
          default_recipient_client,
          NotificationEvent.get_event(label),
          { client_id: obj.id, client_name: obj.company_name },
          'client_' + (active? ? 'enabled' : 'disabled'),
          label,
          user_agent,
          self
        )
        unless jobs.empty?
          jobs.each do |job|
            label = (job.enable ? 'Job Enabled' : 'Job Disabled')
            send_notifications(
              { object: job, from: job.edited_by },
              NotificationEvent.get_event(label),
              { job_id: job.id, job_title: job.title },
              label.split(' ')[-1].downcase,
              label,
              user_agent,
              self
            )
          end
        end
      elsif changed_fields.include?("Account manager ids")
        recipients = default_recipient_client
        send_notifications(
          recipients,
          NotificationEvent.get_event('Client Updated'),
          {
            client_id: obj.id,
            client_name: obj.company_name,
            fields: "Account managers - #{account_managers.pluck(:username).join(', ')}",
          },
          'client_updated',
          'Client Updated',
          user_agent,
          self
        )
      elsif changed_fields.include?("onboarding agent ids")
        recipients = default_recipient_client
        send_notifications(
          recipients,
          NotificationEvent.get_event('Client Updated'),
          {
            client_id: obj.id,
            client_name: obj.company_name,
            fields: "onboarding agents - #{onboarding_agents.pluck(:username).join(', ')}",
          },
          'client_update',
          'Client Updated',
          user_agent,
          self
        )
      elsif changed_fields.include?("Supervisor ids")
        recipients = default_recipient_client
        send_notifications(
          recipients,
          NotificationEvent.get_event('Client Updated'),
          {
            client_id: obj.id,
            client_name: obj.company_name,
            fields: "supervisors - #{supervisors.pluck(:username).join(', ')}",
          },
          'client_updated',
          'Client Updated',
          user_agent,
          self
        )
      else
        changed = changed_fields &
        (
          %w(
            company_name address city state country postal_code website logo about public
            active
          ).
          collect { |x| self.class.human_attribute_name(x) }
        )
        changed += changed_fields.
          select { |x| x.match(/Contact|Recruitment pipeline|Onboarding package|Media/) }
        changed << "Media" if changed_fields.include?('File')
        return if changed.blank?
        send_notifications(
          default_recipient_client,
          NotificationEvent.get_event('Client Updated'),
          {
            client_id: obj.id,
            client_name: obj.company_name,
            fields: changed.join(', '),
          },
          'client_updated',
          'Client Updated',
          user_agent,
          self
        )
      end
    end

    def assign_recruiter_notification_for_client(user_ids = [], edited_by, user_agent)
      return if user_ids.blank?
      users = User.where("id in (?)", user_ids).compact.uniq
      recipients = default_recipient_client
      label = 'Assigned Recruiter to client'
      users.each do |user|
        variables = {
          users_link: "team-members",
          user_name: user.name,
          user_id: user.id,
          client_id: id,
          client_name: company_name,
        }
        recipients[:object] = self
        send_notifications(
          recipients,
          NotificationEvent.get_event(label),
          variables,
          'assigned_recruiters',
          label,
          user_agent,
          edited_by
        )
        ClientMailer.assign_client_to_recruiter_notify(self, user, edited_by).deliver_now
      end
    end

    ######################## new notification system ########################
    def client_created(user, user_agent, obj)
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        key: 'client_created',
        label: 'Client Created',
        message: 'A new client has been created',
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
      options = notification.attributes
      batch = []
      options[:show_on_timeline] = false
      options[:message] = "A new client <a href='/#/clients/#{id}'>#{company_name}</a> has been created"
      options.delete("_id")

      country_id = country_obj["id"]
      users = User.agency_members.
        includes(:industries, :countries).references(:industries, :countries).
        where(industries: { id: industry_id }, countries: { id: country_id }).
        distinct

      users.each do |u|
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

      Message::ClientMessageService.notify_client_created(users, self)
      ClientMailer.notify_am_client_created(primary_account_manager, self).deliver_now
    end

    def send_notification_for_clients_note(changed_fields, note_id, user, user_agent, changes=nil)
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
          message: "Comment '#{note.note}' edited for <a href='/#/clients/#{id}'>#{company_name}</a>",
        })
      else
        options.merge!({
          key: "comment_created",
          label: "Comment Created",
          message: "Comment '#{note.note}' added to <a href='/#/clients/#{id}'>#{company_name}</a>",
        })
      end
    end

    def send_destroy_notification_for_clients_note(note, user, user_agent)
      # timeline
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: user,
        read: true,
        viewed_or_emailed: true,
        visibility: nil,
      }
      options[:created_at] = options[:updated_at] = Time.now

      options.merge!({
        key: "comment_created",
        label: "Comment Deleted",
        message: "Comment '#{note}' deleted for <a href='/#/clients/#{id}}'>#{company_name}</a>",
      })
      Notification.create(options)
    end
  end
end
