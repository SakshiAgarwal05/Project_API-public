module Concerns::CalenderEventsListingValues
  extend ActiveSupport::Concern
  include ActionView::Helpers::NumberHelper

  def created_date
    created_at&.strftime("%m/%d/%Y")
  end

  def event_name
    title
  end

  def scheduled_date
    start_date_time&.strftime("%m/%d/%Y")
  end

  def scheduled_time
    timezone = Timezone.find_by(name: "Pacific Standard Time")
    if start_date_time && end_date_time
      start_time = timezone.get_dst_time(start_date_time).strftime('%I:%M %p')
      end_time = timezone.get_dst_time(end_date_time).strftime('%I:%M %p')
      start_time.concat(' - '+end_time + ' '+ timezone[:abbr])
    end
  end

  def client_name
    if related_to_type.eql?('TalentsJob')
      related_to.job.client.company_name
    elsif related_to_type.eql?('Job')
      related_to.client.company_name
    else
      nil
    end
  end

  def relates_to_job_id
    if related_to_type.eql?('TalentsJob')
      related_to.job.job_id
    elsif related_to_type.eql?('Job')
      related_to.job_id
    else
      nil
    end
  end

  def relates_to_job_title
    if related_to_type.eql?('TalentsJob')
      related_to.job.title
    elsif related_to_type.eql?('Job')
      related_to.title
    else
      nil
    end
  end

  def relates_to_job_type
    if related_to_type.eql?('TalentsJob')
      related_to.job.type_of_job
    elsif related_to_type.eql?('Job')
      related_to.type_of_job
    else
      nil
    end
  end

  def candidate_name
    talents.empty? ? nil : talents.distinct.collect(&:name).join(', ')
  end

  def candidate_email
    talents.empty? ? nil : talents.distinct.pluck(:email).join(', ')
  end

  def candidate_phone
    unless talents.empty?
      phone_numbers = talents.
        distinct.
        joins("right join phones on phones.callable_id = talents.id and phones.primary is true").
        pluck(:number)

      phone_numbers.collect{|number| #display number with country and area code
        begin
          pn = Phoner::Phone.parse(number)
          pn.format("+ %c (%a) %n")
        rescue Exception => e
          number_to_phone(number, area_code: true, delimiter: '')
        end
      }.join(', ')
    end
  end

  def attendees_emails
    event_attendees.pluck(:email).join(',')
  end

  def scheduled_by
    event_creator&.email
  end

  def representing_talent_supplier
    # reprenting recruiter email needed to be displayed
    related_to_type.eql?('TalentsJob') && related_to.signed? ?
      related_to.user.email :
      nil
  end

  def agency_name
    related_to_type.eql?('TalentsJob') &&
      related_to.signed? &&
      !related_to.user.internal_user? ?
        related_to.user.agency.company_name :
        nil
  end
end