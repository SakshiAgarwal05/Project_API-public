module Notifiable
  module NotifiableUser
    attr_accessor :edited_by

    def send_destroy_notification_for_user(user, user_agent)
      return agency.nil?

      self.edited_by = user
      recipients = { from: self }
      send_notifications(
        recipients,
        NotificationEvent.get_event('User Deleted'),
        { user_name: first_name, agency_id: agency.id, agency_name: agency.company_name },
        "user_destroy",
        "User Deleted",
        user_agent,
        self
      )

    end

    def read_invitation(date)
      recipients = { from: nil }
      recipients[:object] = agency if agency
      if agency
        label = 'Member opened invitation'
        notify_with_agency_org(recipients, nil, label, label, 'invited', { date: date }, nil)
      else
        label = 'User opened invitation'
        notify_with_agency_org(recipients, nil, label, label, 'invited', { date: date }, nil)
      end
    end

    def viewed_invitation(date)
      recipients = { from: nil }
      recipients[:object] = agency if agency
      if agency
        label = 'Member viewed invitation'
        notify_with_agency_org(recipients, nil, label, label, 'invited', { date: date }, nil)
      else
        label = 'User viewed invitation'
        notify_with_agency_org(recipients, nil, label, label, 'invited', { date: date }, nil)
      end
    end

    def send_notification_for_user(changed_fields, user, user_agent, changes = nil)
      self.edited_by = user
      recipients = { from: user }
      recipients[:object] = agency if agency

      if (changed_fields & ["tnc"].humanize(self.class)).any? && tnc
        notify_with_agency_org(
          {object: self},
          edited_by,
          'TnC accepted',
          "terms and conditions accepted",
          'updated',
          {},
          user_agent
        )
        UserMailer.send_tnc(self).deliver_later
      end

      if changed_fields.include?('Id') && agency
        label = 'New member to agency'
        notify_with_agency_org(recipients, edited_by, label, label, 'invited', user_agent)
      elsif changed_fields.include?('Id') && !agency
        label = 'New internal user'
        notify_with_agency_org(recipients, edited_by, label, label, 'invited', user_agent)
      elsif confirmed_at && changed_fields.include?('Confirmed at') && !agency
        label = 'Confirmed member'
        notify_with_agency_org(recipients, edited_by, label, label, 'confirmed', user_agent)
      elsif confirmed_at && changed_fields.include?('Confirmed at') && agency
        label = 'Confirmed member agency'
        notify_with_agency_org(recipients, edited_by, label, label, 'confirmed', user_agent)
      elsif changed_fields.include?('reset password')
        label = 'Password Reset'
        notify_with_agency_org(
          { to: self, from: user },
          edited_by,
          label,
          label,
          'password_changed',
          user_agent
        )
      elsif changed_fields.include?('confirmation link')
        label = 'Invited member to agency'
        notify_with_agency_org(recipients, edited_by, label, label, 'invited', user_agent)
      elsif (changed_fields & ["encrypted_password"].humanize(self.class)).any?
        label = 'Password changed'
        notify_with_agency_org(
          { to: self, from: user },
          edited_by,
          label,
          label,
          'password_changed',
          user_agent
        )
      else
        changed = changed_fields & %w(
          contact_no
          email
          first_name
          last_name
          headline
          sin
          avatar
          address
          city
          state
          country
          postal_code
          username
          can_submit_member_directly
          assign_phone
          timezone_id
          number
        ).humanize(self.class)

        changed += changed_fields.
          select { |f| ["Primary role", "Permission ids", "Skill ids", "Industry ids", "Position ids",].include?(f)}.
          collect { |f| f.split(' id').first.pluralize }

        return if changed.blank?
        event_name = "User updated for agency"
        notify_with_agency_org(
          recipients,
          edited_by,
          event_name,
          "user updated",
          'updated',
          { fields: changed.join(', ') },
          user_agent
        )

        fields_for_message = changed_fields & [
          "email",
          "first_name",
          "last_name",
          "username",
          "contact_no",
          "number",
        ].humanize(self.class)

        UserMailer.user_fields_changed(
          user,
          self,
          fields_for_message
        ).deliver_later if confirmed? && fields_for_message.any?
      end
    end

    def tnc_viewed
      notify_with_agency_org(
        {object: self},
        self,
        'TnC viewed',
        "terms and conditions viewed",
        'updated',
        {},
        LoggedinUser.user_agent
      )
    end

    def notify_with_agency_org(recipients, from, event_name, label, key, options = {}, user_agent)
      if agency
        variables = {
          users_link: "team-members",
          user_name: name,
          user_id: id,
          agency_id: agency.id,
          agency_name: agency.company_name,
          user_type: primary_role.titleize,
          created_at: created_at,
          confirmed_at: confirmed_at,
          group_name: teams.first.try(:name)
        }

      else
        variables = {
          users_link: "internal-users",
          user_name: name,
          user_id: id,
          user_type: primary_role.titleize,
          created_at: created_at,
          confirmed_at: confirmed_at
        }

      end
      variables.merge!(options)
      send_notifications(
        recipients,
        NotificationEvent.get_event(event_name),
        variables,
        "user_" + key,
        label,
        user_agent,
        self
      )
    end

  end
end
