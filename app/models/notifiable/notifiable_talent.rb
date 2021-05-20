module Notifiable
  module NotifiableTalent
    attr_accessor :edited_by

    def send_destroy_notification_for_talent(user, user_agent)
      self.edited_by = user
      send_notifications(default_recipient_talent(user),
        NotificationEvent.get_event('Talent Deleted'),
        {talent_name: self.first_name, deleted_by: (user ? "by "+user.first_name : '')},
        "candidate_deleted",
        "Candidate Deleted",
          user_agent, self
      );
    end

    def send_destroy_notification_for_talents_medium(medium, user, user_agent)
      self.edited_by = user
      send_notifications(default_recipient_talent(user),
        NotificationEvent.get_event('Medium Deleted'),
        {medium: medium, obj_name: self.first_name, link: "/#/talent-pool/#{self.id}"},
        "medium_deleted",
        "Medium Deleted",
          user_agent, self
      );
    end

    def send_notification_for_talents_note(changed_fields, note, user, user_agent, changes=nil)
      self.edited_by = user
      send_notifications(default_recipient_talent(user),
        NotificationEvent.get_event('Note Created'),
        {user_name: user.first_name, notable_name: self.first_name, notable_link: "/#/talent-pool/#{self.id}?tab=notes", note: note},
        "note_created",
        "Note Created",
          user_agent, self
      );
    end

    # def send_notification_for_talents_announcement(changed_fields, announcement, user, user_agent, changes=nil)
    #   self.edited_by = user
    #   send_notifications(default_recipient_talent(user),
    #     NotificationEvent.get_event('Announcement Created'),
    #     {user_name: user.first_name, announcementable_name: self.first_name, announcementable_link: "/#/candidates/#{self.id}?tab=discussion"},
    #     "announcement_created",
    #     "Announcement Created",
    #       user_agent, self
    #   );
    # end

    def send_notification_for_new_children_for_talent(obj, user, user_agent, changes=nil)
      self.edited_by = user
      talent = self
      send_notifications(
        {object: self, from: self.added_by},
        NotificationEvent.get_event('Children Created for talent'),
        {
          obj: obj,
          talent_name: talent.name,
          talent_id: talent.id,
          updated_by: user.is_a?(User) ? "by "+user.first_name : ''
        },
        "candidate_#{obj.downcase.split('-').shift.split(' ').join('_')}_created",
        "Candidate's #{obj.downcase.split('-').shift.split(' ').join(' ')} created",
        user_agent,
        self
      )
    end

    def send_notification_for_talent(changed_fields, user, user_agent, changes=nil)
      recipient_hash = default_recipient_talent(user)
      self.edited_by = user
      if changed_fields.include?("Id")#new client
        send_notifications(
          recipient_hash,
          NotificationEvent.get_event('Talent Created'),
          {
            talent_id: self.id,
            talent_name: self.first_name,
            created_by: (user.is_a?(User) ? "by "+user.first_name : '')
          },
          "candidate_created",
          "Candidate Created",
          user_agent, self
        )
      elsif changed_fields.include?(self.class.human_attribute_name(:saved_by_ids))
        saved_by = get_profile_for(user)
        send_notifications(recipient_hash,
          NotificationEvent.get_event(saved_by.nil? ? 'Talent Unsaved' : 'Talent Saved'),
          {talent_id: self.id, talent_name: self.first_name, updated_by: self.edited_by.try(:first_name)},
          "candidate_#{saved_by.nil? ? 'unsaved' : 'saved'}",
          "Candidate #{saved_by.nil? ? 'unsaved' : 'saved'}",
          user_agent, self
        )
      elsif changed_fields.include?(self.class.human_attribute_name("locked_at"))
        send_notifications(recipient_hash,
          NotificationEvent.get_event(locked_at.nil? ? 'Talent Unlocked' : 'Talent Locked'),
          {talent_id: self.id, talent_name: self.first_name, updated_by: self.edited_by.try(:first_name)},
          "candidate_#{locked_at.nil? ? 'enabled' : 'disabled'}",
          "Candidate #{locked_at.nil? ? 'enabled' : 'disabled'}",
          user_agent, self
        )
      elsif changed_fields.include?(self.class.human_attribute_name("resume_path"))
        unless resume_path.blank? && added_by.present? && profiles.last.try(:complete)
          send_notifications(recipient_hash,
            NotificationEvent.get_event('Talent Profile Incomplete'),
            {talent_id: self.id, talent_name: self.first_name, updated_by: user.is_a?(User) ? "by "+user.first_name : ''},
            "candidate_incomplete_profile",
            "Candidate Profile Incomplete",
          user_agent, self
          )
          talents_job = self.talents_jobs.not_withdrawn.where(stage: nil, interested: true).last
        end
      elsif changed_fields.include?('reset password')
        send_notifications(recipient_hash,
          NotificationEvent.get_event('Password Reset Talent'),
          {talent_id: self.id, talent_name: self.first_name},
          "candidate_updated",
          "Candidate Updated",
          user_agent, self
        )
      elsif changed_fields.include?('confirmation link')
        send_notifications(recipient_hash,
          NotificationEvent.get_event('Talent confirmed'),
          {talent_id: self.id, talent_name: self.first_name},
          "candidate_updated",
          "Candidate Updated",
          user_agent, self
        )
      else
        changed = changed_fields & (%w(email username phone first_name last_name headline sin avatar address city state country
        postal_code resume summary willing_to_relocate current_benefits start_date hobbies work_authorization
        current_pay_range_min current_pay_range_max current_pay_period current_currency expected_pay_range_min
        expected_pay_range_max expected_pay_period expected_currency compensation_notes compensation_benefits
        timezone_id hired).collect{|field_name| self.class.human_attribute_name(field_name)})
        changed += changed_fields.select{|field_name| field_name.match(/Experience|Education|Language/)}
        changed += changed_fields.select{|field_name| ["Skill ids", "Industry ids", "Position ids"].include?(field_name)}.collect{|field_name| field_name.split(' id').first.pluralize}
        return if changed.blank?
        send_notifications(recipient_hash,
          NotificationEvent.get_event('Talent Updated'),
          {talent_id: self.id.to_s, talent_name: self.first_name, updated_by: user.is_a?(User) ? "by "+user.first_name : '', fields: changed.join(', ')},
          "candidate_updated",
          "Candidate Updated",
          user_agent, self
        )
      end
    end

    def default_recipient_talent(user)
      user_ids = profiles.where(profilable_type: "User").pluck(:profilable_id)+self.talents_jobs.active.pluck(:user_id)
      users = User.visible_to(user).where(id: user_ids).pluck(:id)
      recipient_hash = {object: self, from_id: users}
    end

    def send_notification_for_talents_note(changed_fields, note_id, user, user_agent, changes=nil)
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
        visibility: note.visibility
      }
      options[:created_at] = options[:updated_at] = Time.now

      if !changed_fields.include?('id')
        options.merge!({
        key: "comment_created",
        label: "Comment Edited",
        message: "Comment '#{note.note}' edited for <a href='/#/talent-pool/#{self.id}'>#{self.name}</a>",
        })
      else
        options.merge!({
        key: "comment_created",
        label: "Comment Created",
        message: "Comment '#{note.note}' added to <a href='/#/talent-pool/#{self.id}'>#{self.name}</a>",
        })
      end
    end

    def send_destroy_notification_for_talents_note(note, user, user_agent)
      # timeline
      options = {
        show_on_timeline: true,
        user_agent: user_agent,
        object: self,
        receiver: self,
        from: user,
        read: true,
        viewed_or_emailed: true,
        visibility: nil
      }
      options[:created_at] = options[:updated_at] = Time.now

      options.merge!({
      key: "comment_created",
      label: "Comment Deleted",
      message: "Comment '#{note}' deleted for <a href='/#/talent-pool/#{self.id}}'>#{self.name}</a>",
      })
      notification = Notification.create(options)
    end
  end
end
