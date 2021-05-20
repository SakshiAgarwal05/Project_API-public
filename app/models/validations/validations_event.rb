module Validations
  module ValidationsEvent
    def self.included(receiver)
      receiver.class_eval do
        validates :event_type, :title, presence: true
        validates :location, presence: {if: Proc.new{|x| x.event_type.eql?("Onsite Interview")}}
        validates :event_type, inclusion: {
          in: Event::EVENT_TYPES + Event::NEW_EVENT_TYPES
        }, allow_nil: true

        validates :update_note, html_content_length: { maximum: 500 }
        validates :decline_reason, html_content_length: { maximum: 500 }

        validates :start_date_time, :end_date_time, presence: { unless: :request }
        validate :compare_time
        validate :atleast_one_attendee_on_create, on: :create
        validate :atleast_one_attendee_on_update, on: :update
        validate :organizer_optional_rule
        validate :check_time_slot
      end
    end

    ########################
    private
    ########################

    def organizer_optional_rule
      data = event_attendees.to_a.pluck(:is_organizer, :optional)
      return unless data.include?([true, true])
      if data.count <= 2 ||
        !event_attendees.to_a.pluck(:is_organizer, :is_host, :optional).include?([false, true, false])

        errors.add(:base, 'You cannot make the organizer optional if you do not have another non-optional host')
      end
    end

    def atleast_one_attendee_on_create
      if event_attendees.to_a.pluck(:is_organizer).count(false) < 1
        errors.add(:base, 'Please, select atleast one attendee')
      end
    end

    def atleast_one_attendee_on_update
      if event_attendees.reject { |x| x.marked_for_destruction? }.count <= 1
        errors.add(:base, 'Please, select atleast one attendee')
      end
    end

    # end_date_time must be greater than start_date_time
    def compare_time
      self.errors.add(:start_date_time, "must be greater than #{Time.now.to_formatted_s(:long)}") if start_date_time && start_date_time <= Time.now
      self.errors.add(:end_date_time, "must be greater than start date/time") if end_date_time && end_date_time <= start_date_time
    end

    # There should be atleast 2 timeslots if request is true
    def check_time_slot
      self.errors.add(:base, 'Add atleast two time slots.') if request && time_slots.empty?
    end
  end
end
