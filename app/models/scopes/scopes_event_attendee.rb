module Scopes
  module ScopesEventAttendee
    def self.included(receiver)
      receiver.class_eval do
        scope :hosts, -> { where(is_host: true) }
        scope :organizer, -> { where(is_organizer: true) }
        scope :non_organizer, -> { where(is_organizer: false) }
        scope :user_attendees, -> { where.not(user_id: nil) }
        scope :talent_attendees, -> { where.not(talent_id: nil) }
        scope :unremoved, -> { where(remove_event: false) }
        scope :optional, -> { where(optional: true) }
        scope :non_optional, -> { where(optional: false) }
        scope :no_attendees, -> { where(status: 'No') }
        scope :yes_attendees, -> { where(status: 'Yes') }
        scope :maybe_attendees, -> { where(status: 'Maybe') }
        scope :pending_attendees, -> { where(status: 'pending') }
        scope :attendees_events, ->(event_ids) { where(event_id: event_ids) }
        scope :attendees_users, -> (user_ids) { where(user_id: user_ids) }
        scope :common_order, -> { order(is_organizer: :desc, is_host: :desc, email: :asc) }
      end
    end
  end
end
