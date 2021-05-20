require 'csmm/match_maker'
module ModelCallback
  module CallbacksEvent
    def self.included(receiver)
      receiver.class_eval do
        before_validation :init_fields
        after_create :make_creator_organizer_and_host_confirmed
        after_save :schedule_reminder
        after_save :update_talents_jobs
        after_save :update_pipeline_status
        #after_save :reset_attendee_slots_on_event_confirmation
        after_save :actions_on_declining_event
        after_update :reset_attendees
        after_save :request_false_when_event_scheduled

        after_save :handle_generic_action_metrics
      end
    end

    ########################
    private
    ########################

    # initialize fields based on if event is scheduled or requested
    def init_fields
      self.start_date_time = DateTime.parse(start_date_time) if start_date_time.is_a?(String)
      self.end_date_time = DateTime.parse(end_date_time) if start_date_time.is_a?(String)
      self.token = Devise.friendly_token
      # self.agency_id = attendees.pluck(:agency_id).compact.first unless related_to.is_a?(TalentsJob)
      self.confirmed = true unless request
      if related_to.is_a?(TalentsJob)
        self.job_id = related_to.job_id
        self.client_id = related_to.client_id
        self.tj_user_id = related_to.user_id
        self.agency_id = related_to.agency_id
      elsif related_to.is_a?(Job)
        self.job_id = related_to.id
        self.client_id = related_to.client_id
      elsif related_to.is_a?(Client)
        self.client_id = related_to_id
      end
      self.multi_slot_event = request
    end

    # send a reminder to all attendee for the event
    def schedule_reminder
      return if reminder_in_minutes.nil? || reminder_in_minutes.zero? || start_date_time.nil?
      schedule_at = start_date_time - reminder_in_minutes.minutes
      job = EventJob.set(wait_until: schedule_at).perform_later(id, changed)
    end

    def update_talents_jobs
      return unless (changed.include?('end_date_time') && end_date_time)
      return unless related_to.is_a?(TalentsJob)
      SetPipelineInProgressJob.set(wait_until: start_date_time).perform_later(id)
      UnderReviewAfterExpireJob.set(wait_until: end_date_time).perform_later(id)
    end

    def update_pipeline_status
      return unless related_to.is_a?(TalentsJob)
      related_to.event_id = id
      ct = related_to.completed_transitions.where(event_id: id).first
      return unless ct&.pipeline_step&.eventable && ct.event.eql?(self)
      ct.update_columns(tag: 'declined') if declined
      ct.update_columns(tag: 'scheduled') if start_date_time && start_date_time > Time.now.utc
    end

    def handle_generic_action_metrics
      return unless related_to.present?
      return unless related_to_type == 'TalentsJob' || related_to_type == 'Job'
      obj_values = {
        job_id: related_to_type == 'TalentsJob' ? related_to.job_id : related_to_id,
        time: Time.zone.now.to_s,
        action_model: self.class.to_s,
        changes: changes.keys,
        _version: 2
      }
      CsmmTaskHandlerJob.set(wait: 5.seconds).
        perform_later('calculate_job_generic_action_metrics', obj_values)
    end

    def make_creator_organizer_and_host_confirmed
      event_attendees.create(email: user.email) unless event_attendees.attendees_users(user_id).any?

      event_attendees.attendees_users(user_id).update_all(is_organizer: true, status: 'Yes')

      if start_date_time.present?
        event_attendees.hosts.update_all(status: 'Yes')
      elsif start_date_time.nil? && time_slots.any?
        event_attendees.organizer.update_all(confirmed_slots: time_slots.pluck(:id))
      end
    end

    # def reset_attendee_slots_on_event_confirmation
    #   return unless changes
    #   if changes.include?('confirmed') && confirmed && request.is_false?
    #     event_attendees.update_all(confirmed_slots: [])
    #   end
    # end

    def actions_on_declining_event
      if declined_changed? && declined.is_true?
        event_attendees.update_all(status: 'No', confirmed_slots: [])
      end
    end

    def request_false_when_event_scheduled
      return if declined || request.is_false? || start_date_time.blank?
      update_columns(request: false, confirmed: true) if start_date_time > Time.now.utc
    end

    def reset_attendees
      return unless changes
      return unless updated_by
      if (changes['start_date_time'] &&
        !changes['start_date_time'].first.nil? &&
        !changes['start_date_time'].last.nil?) ||
        (changes['end_date_time'] &&
        !changes['end_date_time'].first.nil? &&
        !changes['end_date_time'].last.nil?) ||
        location_changed? || latitude_changed? || longitude_changed? ||
        meeting_url_changed? || dial_in_number_changed? || access_code_changed? ||
        timezone_id_changed?

        attendees = event_attendees.non_organizer
        current_host = event_attendees.where(user_id: updated_by.id, is_host: true)
        if current_host.any?
          attendees = attendees.where('user_id IS NULL OR user_id != ?', updated_by.id)
        end
        attendees.update_all(status: 'pending', confirmed_slots: [])
        self.required_changes = true
      end
    end
  end
end
