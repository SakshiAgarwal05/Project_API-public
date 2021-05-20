module ModelCallback
  module CallbacksEventAttendee
    def self.included(receiver)
      receiver.class_eval do
        before_validation :init_object_and_check_for_valid_attendees
        before_destroy :can_destroy
        before_save :confirm_attendee_if_selected_time_slot
        after_save :auto_schedule_event
        before_create :set_token
      end
    end

    ########################

    private

    ########################

    def init_object_and_check_for_valid_attendees
      fine = false
      creator = event.user
      job = event.job
      return unless job
      user_or_talent = User.confirmed.find_by_email(email) ||
        Talent.find_by_email(email) ||
        Email.where(mailable_type: 'User').where.not(confirmed_at: nil).
          find_by_email(email)&.
          mailable ||
        Email.where(mailable_type: 'Talent').
          find_by_email(email)&.
          mailable

      if user_or_talent
        ut_id = user_or_talent.id
        if user_or_talent.is_a?(User)
          fine =
            if ['super admin', 'admin', 'customer support agent'].include?(user_or_talent.primary_role)
              true
            elsif creator.internal_user?
              job.notifiers.include?(ut_id) ||
              job.picked_by.where(id: ut_id).exists? ||
              job.account_manager_ids.include?(ut_id) ||
              job.supervisor_ids.include?(ut_id) ||
              job.onboarding_agent_ids.include?(ut_id) ||
              job.client.assignables.joins(:user).where(users: { id: ut_id }).any? ||
              job.all_ho_users(creator).include?(user_or_talent)
            elsif creator.agency_user?
              job.picked_by.where(agency_id: creator.agency_id, id: ut_id).exists? ||
              job.internal_notifiers.include?(ut_id)
            elsif creator.hiring_org_user?
              job.internal_notifiers.include?(ut_id) ||
              job.all_ho_users(creator).include?(user_or_talent)
            end
        elsif user_or_talent.is_a?(Talent)
          tjs = job&.talents_jobs.where.not(withdrawn: true)
          fine =
            if creator.internal_user?
              tjs.where(talent_id: ut_id).any?
            elsif creator.agency_user?
              tjs.where(agency_id: creator.agency_id).where(talent_id: ut_id).any?
            elsif creator.hiring_org_user?
              tjs.where(hiring_organization_id: creator.hiring_organization_id, talent_id: ut_id).any? ||
              tjs.visible_ho_talents(creator).where(talent_id: ut_id).any?
            end
        end
      else
        if creator.agency_user? || creator.hiring_org_user?
          website = creator.agency&.website || creator.hiring_organization&.website
          domain = creator.send('domain_match_for_ho_and_agency_attendee', "#{website}")
          errors.add(:base, "#{email} should match with website domain") unless email.match(/@(#{domain})$/i)
        elsif creator.internal_user?
          unless email.include?('@crowdstaffing.com')
            websites = (job.picked_by.joins(:agency).pluck("agencies.website").compact.uniq +
              [job.hiring_organization&.website]).compact.uniq

            unless websites.any? { |s| s.include?(email.split('@').last) }
              errors.add(:base, "#{email} does not match with any website domain")
            end
          end
        end
      end
      if fine.is_true? && user_or_talent
        self.user_id = user_or_talent.id if user_or_talent.is_a?(User)
        self.talent_id = user_or_talent.id if user_or_talent.is_a?(Talent)
      elsif fine.is_false? && user_or_talent
        errors.add(:base, "You cannot add #{email} as attendee.")
      end
    end

    def can_destroy
      return unless is_organizer.is_true?
      event.errors.add(:base, 'You cannot remove organizer from list of attendees.')
      throw :abort
    end

    def confirm_attendee_if_selected_time_slot
      return unless event
      return if status.eql?('Yes') || !event.start_date_time.nil?
      self.status = 'Yes' if confirmed_slots_changed? && !confirmed_slots.nil? && confirmed_slots.any?
    end

    def auto_schedule_event
      return unless confirmed_slots_changed?
      # return if a non-optional attendee selects no to the event
      return if optional.is_false? && status.eql?('No')
      return if event.declined || event.start_date_time.present?
      non_optional_attendees = event.event_attendees.non_optional
      common_slot = non_optional_attendees.pluck(:confirmed_slots).inject { |x, e| (x.nil? ? [] : x) & (e.nil? ? [] : e) }
      return unless common_slot.count.eql? 1
      time_slot = TimeSlot.find(common_slot.first)
      if time_slot
        if event.update_attributes(
          request: false,
          confirmed: true,
          start_date_time: time_slot.start_date_time,
          end_date_time: time_slot.end_date_time,
          timezone_id: time_slot.timezone_id
        )

          SystemNotifications.perform_later(event, 'event_confirmed', nil, nil)
          event.email_for_event(nil, event.is_pipeline_event?, nil, 'Confirmed')
        end
      end
    end

    def set_token
      self.invitation_token = Devise.friendly_token
    end
  end
end
