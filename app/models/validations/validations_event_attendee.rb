module Validations
  module ValidationsEventAttendee
    # include FilePathValidator
    def self.included(receiver)
      receiver.class_eval do
        validates :email, presence: true
        validates :note, html_content_length: { maximum: 500 }

        validate :talent_and_external_user_cannot_be_host
        validate :organizer_withdrawning_rule
        validate :multiple_time_slot_selecting_yes_rule
        validate :check_valid_slots
      end
    end

    ########################
    private
    ########################
    def talent_and_external_user_cannot_be_host
      return unless is_host.is_true?
      if talent_id.present? || (talent_id.blank? && user_id.blank?)
        errors.add(:base, 'A candidate cannot be designated as a host')
      end
    end

    #An organizer can say no to a meeting without deleting/canceling the event provided the number of attendees are greater than 2 AND there is at least one other designated HOST.
    def organizer_withdrawning_rule
      return unless status_changed?
      all_attendees = event.event_attendees
      if ['No', 'Maybe'].include?(status) &&
        is_organizer.is_true? &&
        (all_attendees.count <= 2 ||
          all_attendees.hosts.non_optional.non_organizer.empty?
        )
        errors.add(:base, 'Organizer cannot say no to this event.')
      end
    end

    def multiple_time_slot_selecting_yes_rule
      return if event.start_date_time # check only for requested events
      return unless status_changed?
      if changes['status'].last.eql?('Yes') && confirmed_slots.count.zero?
        errors.add(:base, 'You must select a timeslot.')
      end
    end

    def check_valid_slots
      return unless confirmed_slots_changed?
      if TimeSlot.where("id in (?) AND start_date_time < ?", confirmed_slots, Time.now.utc).any?
        errors.add(:base, "Cannot approve timeslot as it has expired.")
      end
    end
  end
end
