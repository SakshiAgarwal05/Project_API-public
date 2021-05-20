module Fields
  # FieldsEvent
  module FieldsEvent
    def self.included(receiver)
      receiver.class_eval do
        # BelongsTo Association order ascending.

        belongs_to :timezone
        belongs_to :agency, validate: false
        belongs_to :client, validate: false
        belongs_to :declined_by, polymorphic: true
        belongs_to :job, validate: false
        belongs_to :related_to, polymorphic: true, validate: false
        belongs_to :user, inverse_of: :event_created
        belongs_to :tj_user, class_name: 'User', validate: false

        # HasMany Association order ascending.
        has_many :event_attendees, dependent: :destroy
        has_many :media, as: :mediable
        has_many :time_slots

        # HasMany Through Association order ascending.
        # has_many :events_users, dependent: :destroy, validate: false
        # has_many :attendees, through: :events_users, source: :user, validate: :false

        # has_many :events_talents, dependent: :destroy
        # has_many :talents, through: :events_talents, source: :talent, validate: false

        has_many :users, through: :event_attendees
        has_many :talents, through: :event_attendees

        accepts_nested_attributes_for :event_attendees, allow_destroy: true
        accepts_nested_attributes_for :time_slots, allow_destroy: true
        accepts_nested_attributes_for :media, allow_destroy: true

        alias_for_nested_attributes :event_attendees=, :event_attendees_attributes=
        alias_for_nested_attributes :time_slots=, :time_slots_attributes=
        alias_for_nested_attributes :media=, :media_attributes=

        alias_attribute :event_creator, :user
      end
    end

    def final_time_slot=(val)
      return unless request
      time_slot = time_slots.find(val)
      unless time_slot
        errors.add(:base, 'time slot is invalid.')
        return self
      end
      if time_slot.start_date_time < Time.zone.now
        errors.add(:base, "can't approve timeslot as its expired.")
        return self
      end
      self.start_date_time = time_slot.start_date_time
      self.end_date_time = time_slot.end_date_time
    end
  end
end
