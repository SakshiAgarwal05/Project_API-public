module Notifiable
  module NotifiableAgency
    attr_accessor :edited_by

    def send_destroy_notification_for_agency(user, user_agent)
      self.edited_by = user
      send_notifications(
        default_recipient_agency,
        NotificationEvent.get_event('Agency Deleted'),
        { agency_name: company_name },
        'agency_deleted',
        'Agency Deleted',
        user_agent,
        self
      );
    end

    def send_destroy_notification_for_agency_contact(contact, user, user_agent)
      self.edited_by = user
      send_notifications(
        default_recipient_agency,
        NotificationEvent.get_event('Contact Deleted'),
        { contact: contact, contactable_name: self.company_name, link: "/#/agencies/#{self.id}" },
        'contact_deleted',
        'Contact Deleted',
        user_agent,
        self
      );
    end

    def send_destroy_notification_for_agency_medium(medium, user, user_agent)
      self.edited_by = user
      send_notifications(
        default_recipient_agency,
        NotificationEvent.get_event('Medium Deleted'),
        { medium: medium, obj_name: self.company_name, link: "/#/agencies/#{self.id}" },
        'medium_deleted',
        'Medium Deleted',
        user_agent,
        self
      );
    end

    def send_notification_for_agencys_note(changed_fields, note, user, user_agent, changes=nil)
      self.edited_by = user
      send_notifications(
        default_recipient_agency,
        NotificationEvent.get_event('Note Created'),
        { user_name: user.first_name,
          notable_name: company_name,
          notable_link: "/#/agencies/#{self.id}",
          note: note
        },
        'note_created',
        'Note Created',
        user_agent,
        self
      );
    end

    def send_notification_for_new_children_for_agency(obj, user, user_agent, changes=nil)
      self.edited_by = user
      agency = self
      send_notifications(
        { object: self, from: self.created_by },
        NotificationEvent.get_event('Children Created for agency'),
        { obj: obj,
          agency_name: agency.company_name,
          agency_id: agency.id,
          updated_by: user.is_a?(User) ? "by "+user.first_name : ''
        },
        "#{self.class.collection_name.to_s..singularize.downcase}_created",
        "Agency's #{self.class.collection_name.to_s.gsub('_', ' ').singularize} created",
        user_agent,
        self
      );
    end

    def send_notification_for_agency(changed_fields, user, user_agent, changes=nil)
      self.edited_by = user
      obj = (self.is_a?(Agency) ? self : self.contactable)
      if changed_fields.include?('Id')#new agency
        send_notifications(
          {object: self, from: self.created_by},
          NotificationEvent.get_event('Agency Created'),
          { agency_id: obj.id, agency_name: obj.company_name },
          'agency_created',
          'Agency Created',
          user_agent,
          self
        )
      elsif changed_fields.include?(self.class.human_attribute_name('locked_at'))
        label = (self.enable ? 'Agency Enabled' : 'Agency Disabled')
        send_notifications(
          default_recipient_agency,
          NotificationEvent.get_event(label),
          { agency_id: obj.id, agency_name: obj.company_name },
          "agency_"+label.split(' ').last.downcase,
          label,
          user_agent,
          self
        )
      else
        changed = changed_fields & (%w(company_name address city state country postal_code logo timezone_id).collect{|x|  self.class.human_attribute_name(x)})
        changed += changed_fields.select{|x| x.match(/Contact|Media/)}
        changed += changed_fields.select{|f| ["Skill ids", "Industry ids", "Position ids"].include?(f)}.collect{|f| f.split(' id').first.pluralize}
        changed << "Media" if changed_fields.include?('File')
        return if changed.blank?
        send_notifications(
          default_recipient_agency,
          NotificationEvent.get_event('Agency Updated'),
          { agency_id: obj.id, agency_name: obj.company_name, fields: changed.join(', ') },
          'agency_updated',
          'Agency Updated',
          user_agent,
          self
        );
      end
    end
  end
end
