class Event < ApplicationRecord
  acts_as_paranoid
  include AddAbility
  include Constants::ConstantsEvent
  include Fields::FieldsEvent
  include Validations::ValidationsEvent
  include ModelCallback::CallbacksEvent
  include Scopes::ScopesEvent
  include Notifiable
  include Concerns::CalenderEventsListingValues
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include ES::ESEvent
  require 'icalendar'

  attr_accessor :required_changes, :multi_slot_event, :updated_by

  def self.get_talents_jobs_query(user)
    sql = TalentsJob.unscoped.visible_to(user).to_sql
    conditions = sql.split('WHERE ')[1..-1].join(' WHERE ')
    conditions.gsub(/talents_jobs/, 'events').gsub(/events.user_id/, "events.tj_user_id")
  end

  def finished
    return false if end_date_time.nil?
    end_date_time <= Time.now
  end

  def status(user = nil, attendee = nil)
    if declined ||
      (event_attendees.where(is_organizer: false, status: 'No').count.
        eql?(event_attendees.non_organizer.count) && event_attendees.count > 0)
      return 'Declined'
    end

    if (start_date_time.blank? || request.is_true?) && time_slots.where("start_date_time > ?", Time.now.utc).count.zero?
      return 'Expired'
    end

    if start_date_time.blank? || request.is_true?
      if (user && user.event_attendees.attendees_events(id).any?) ||
        (attendee && event_attendees.where(id: attendee.id).any?)
        if (user && user.event_attendees.no_attendees.attendees_events(id).exists?) ||
          (attendee && attendee.status.eql?('No'))
          return 'Declined'
        else
          return 'Pending'
        end
      end
      return 'Pending'
    end

    if start_date_time > Time.now.utc
      if (user && user.event_attendees.attendees_events(id).any?) ||
        (attendee && event_attendees.where(id: attendee.id).any?)

        if (user && user.event_attendees.pending_attendees.attendees_events(id).exists?) ||
          (attendee && attendee.status.eql?('pending'))
          return 'Pending'
        end

        if (user && user.event_attendees.maybe_attendees.attendees_events(id).exists?) ||
          (attendee && attendee.status.eql?('Maybe'))
          return 'Maybe'
        end

        if (user && user.event_attendees.yes_attendees.attendees_events(id).exists?) ||
          (attendee && attendee.status.eql?('Yes'))
          return 'Scheduled'
        end

        if (user && user.event_attendees.no_attendees.attendees_events(id).exists?) ||
          (attendee && attendee.status.eql?('No'))
          return 'Declined'
        end
      end
      return 'Scheduled'
    end

    if start_date_time <= Time.now.utc && end_date_time > Time.now.utc
      if (user && user.event_attendees.attendees_events(id).any?) ||
        (attendee && event_attendees.where(id: attendee.id).any?)

        if (user && user.event_attendees.yes_attendees.attendees_events(id).exists?) ||
          (attendee && attendee.status.eql?('Yes'))
          return 'In-progress'
        end

        if (user && user.event_attendees.attendees_events(id).where(status: ['No', 'pending', 'Maybe']).exists?) ||
          (attendee && ['No', 'pending', 'Maybe'].include?(attendee.status))
          return 'Declined'
        end
      end
      return 'In-progress'
    end

    if finished
      if (user && user.event_attendees.attendees_events(id).any?) ||
        (attendee && event_attendees.where(id: attendee.id).any?)

        if (user && user.event_attendees.yes_attendees.attendees_events(id).exists?) ||
          (attendee && attendee.status.eql?('Yes'))
          return 'Complete'
        end

        if (user && user.event_attendees.attendees_events(id).where(status: ['No', 'pending', 'Maybe']).exists?) ||
          (attendee && ['No', 'pending', 'Maybe'].include?(attendee.status))
          return 'Declined'
        end
      end
      return 'Complete'
    end
  end

  def email_decision(previous_changes, current_user_id)
    email_for_event(previous_changes, is_pipeline_event?, current_user_id)
  end

  def email_for_event(changes, pipeline_event = false, current_user_id = nil, status = nil, new_attendees = [], only_external = false)
    status = current_transition(changes) if status.nil?

    if status.eql?('Cancelled')
      attendees = event_attendees.where('user_id IS NULL OR user_id != ?', declined_by_id)
    elsif status.eql?('Confirmed')
      attendees = if current_user_id.nil?
                    event_attendees.where.not(status: 'No')
                  else
                    event_attendees.where('user_id IS NULL OR user_id != ?', current_user_id)
                  end
    else
      attendees = if current_user_id.nil?
                    event_attendees
                  else
                    event_attendees.
                      where('user_id IS NULL OR user_id != ?', current_user_id)
                  end
    end

    attendees = attendees.where.not(email: new_attendees) if new_attendees.any?
    attendees = attendees.where(user_id: nil) if only_external.is_true?

    Message::EventMessageService.send('send_event', self, attendees, changes, status)

    if pipeline_event.is_true? && Event::TALENT_EMAIL_EVENT_STATUS.include?(status)
      attendees.talent_attendees.each do |attendee|
        talent = attendee.talent
        TalentMailer.account_verify_notify(talent).deliver_later if !talent&.confirmed?
      end
    end
  end

  def email_for_newly_added_attendee(new_attendees, changes)
    attendees = event_attendees.where(email: new_attendees)
    new_attendee_status = request.is_true? ? 'Requested' : 'Scheduled'
    Message::EventMessageService.send('send_event', self, attendees, changes, new_attendee_status)
    if is_pipeline_event? && Event::TALENT_EMAIL_EVENT_STATUS.include?(new_attendee_status)
      attendees.talent_attendees.each do |attendee|
        TalentMailer.account_verify_notify(talent).deliver_later if !attendee.talent&.confirmed?
      end
    end
  end

  def inform_organizer_and_host(attendee)
    attendees = event_attendees.where.not(id: attendee.id)
    Message::EventMessageService.send(
      "inform_attendee_#{attendee.status}",
      self,
      attendees.organizer.or(attendees.hosts).uniq,
      attendee
    )
  end

  def inform_organizer_confirmed_slots(attendee)
    Message::EventMessageService.send(
      'inform_organizer_attendee_confirmed_slots',
      self,
      event_attendees.organizer,
      attendee
    )
  end

  def related_to_text
    return if related_to.nil?
    case related_to_type
    when 'TalentsJob'
      return related_to.job.title
    when 'Job'
      return related_to.title
    when 'Agency', 'Client'
      return related_to.company_name
    when 'Talent'
      return related_to.first_name
    end
  end

  def current_transition(changes)
    if changes && changes['start_date_time'] &&
      changes['start_date_time'].first.nil? &&
      !changes['start_date_time'].last.nil? &&
      (multi_slot_event.is_false? || multi_slot_event.nil?)
      'Scheduled'
    elsif changes.include?('id') && start_date_time.nil?
      'Requested'
    elsif changes.include?('confirmed') && confirmed
      'Confirmed'
    elsif changes.include?('declined') && declined
      'Cancelled'
    else
      'Updated'
    end
  end

  def related_to_obj
    return if related_to.nil?
    related_to_type == 'TalentsJob' ? job : related_to
  end

  def is_pipeline_event?
    related_to && related_to.is_a?(TalentsJob)
  end

  def event_cancel_on_job_close(job, obj_class)
    update_attributes(
      declined: true,
      declined_by: User.crowdstaffing,
      decline_reason: "The #{job.title} position at #{job.client.company_name} is now closed and no longer considering any applicants."
    )

    event_attendees.user_attendees.each do |attendee|
      EventMailer.job_close_event_decline_email(self, attendee).deliver_now
    end

    Message::EventMessageService.job_close_event_decline_email(self, event_attendees.talent_attendees)
  end

  def event_related_objs
    event_hash = { event: { id: id } }

    case related_to_type
    when 'TalentsJob'
      event_hash.merge!(related_to.talents_job_related_objs)
    when 'Job'
      event_hash.merge!(related_to.job_related_objs)
    when 'Talent'
      event_hash.merge!(related_to.talent_related_objs)
    when 'Client'
      event_hash.merge!(related_to.client_related_objs)
    when 'User'
      event_hash.merge!(related_to.user_related_objs)
    end
  end

  def attendees_available
    data = {}
    time_slots.each do |time_slot|
      data[time_slot.id] = event_attendees.
        where(":slots = ANY(confirmed_slots)", slots: time_slot.id).count
    end
    data
  end

  def attendees_tally
    event_attendees.group(:status).count
  end

  def upcoming
    (start_date_time.present? && start_date_time > Time.now) ||
    (start_date_time.nil? && time_slots.where("start_date_time > ?", Time.now.utc).count > 0)
  end

  def ics_calendar
    cal = Icalendar::Calendar.new
    cal.x_wr_calname = title
    cal.event do |ical_e|
      ical_e.dtstart = Icalendar::Values::DateTime.new start_date_time, 'tzid' => 'UTC' if start_date_time
      ical_e.dtend = Icalendar::Values::DateTime.new end_date_time, 'tzid' => 'UTC' if end_date_time
      ical_e.attendee = event_attendees.pluck(:email).collect { |email| "mailto:" + email } if event_attendees
      ical_e.location = location if location
      ical_e.summary = title if title

      if note || meeting_url || access_code || dial_in_number
        description = ""
        description += note if note
        description += " Conference URL: #{meeting_url}" if meeting_url
        description += " Dial-In Number: #{dial_in_number}" if dial_in_number
        description += " PIN: #{access_code}" if access_code
        ical_e.description = description
      end

      ical_e.url = meeting_url if meeting_url
    end
    cal
  end
end
