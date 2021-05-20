module Notifiable
  module NotifiableTeam
    attr_accessor :edited_by

    def send_destroy_notification_for_team(user, user_agent)
      self.edited_by = user
      recipients = {object: self, from: self.edited_by}
      send_notifications(recipients,
        NotificationEvent.get_event('Team Deleted'),
        {team_name: self.name, agency_name: (self.agency.company_name rescue nil), agency_id: self.agency_id},
        "team_destroy",
        "Team Deleted",
        user_agent, self
      );
    end

    def send_notification_for_teams_note(changed_fields, note, user, user_agent, changes=nil)
      self.edited_by = user
      send_notifications(default_recipient_team,
        NotificationEvent.get_event('Note Created'),
        {user_name: user.first_name, notable_name: self.name, notable_link: "/#/teams/#{self.id}",
         note: note},
        "note_created",
        "Note Created",
        user_agent, self
      );
    end

    def send_notification_for_team(changed_fields, user, user_agent, changes=nil)
      self.edited_by = user
        if changed_fields.include?('Id') # new team
        send_notifications(
          {object: self, from: created_by},
          NotificationEvent.get_event('Team Created'),
          { team_id: id, team_name: name },
          'team_created',
          'Team Created',
          user_agent,
          self

        )
      elsif changed_fields.include?(self.class.human_attribute_name('enable'))
        label = enable ? 'Team Enabled' : 'Team Disabled'
        send_notifications(
          default_recipient_team,
          NotificationEvent.get_event(label),
          { team_id: id, team_name: name },
          "team_"+enable ? 'enabled' : 'disabled',
          label,
          user_agent,
          self

        )
      else
        changed = changed_fields & (%w(name logo country state timezone_id team_id).collect{|x|  self.class.human_attribute_name(x)})
        changed += changed_fields.select{|f| ["Skill ids", "Industry ids", "Position ids"].include?(f)}.collect{|f| f.split(' id').first.pluralize}
        return if changed.blank?
        send_notifications(default_recipient_team,
          NotificationEvent.get_event('Team Updated'),
          {team_id: self.id, team_name: self.name, fields: changed.join(', ')},
          "team_updated",
          "Team Updated",
          user_agent,
          self

        );
      end
    end
  end
end
