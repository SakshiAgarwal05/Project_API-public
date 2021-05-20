module Concerns::JobListingTabValues
  extend ActiveSupport::Concern
  include Admin::JobsHelper
  include Metrics::CommonMetrics
  include ApplicationHelper


  module ClassMethods
    def find_aging(first_date, second_date)
      (first_date.to_date - second_date.to_date).to_i rescue nil
    end
  end

  def published_date
    published_at&.strftime("%m/%d/%Y")
  end

  def client_name
    client.company_name
  end

  def hiring_organization_name
    hiring_organization.company_relationship
  end

  def job_aging #find job aging
    return '0 Days' unless published_at  #in case of draft jobs
    closed = stage.eql?('Closed')
    if !reason_to_reopen.blank?
      results = notifications.
        where(show_on_timeline: true, key: ['job_closed', 'job_filled', 'job_reopened']).
        distinct.
        order('created_at desc').
        pluck(:key, :created_at)

      # handle concorrent duplicated notifications
      results.delete_if{|key, date|
        results.index([key, date]).positive? && results[results.index([key, date]) - 1].first.eql?(key)
      }

      # get only dates
      results = results.collect{|key, date| date}
      last_transition_age = Job.find_aging(Time.now, results.delete_at(0)) if !closed

      remaining_transition_days = 0
      while results.count >= 2 do
        days = Job.find_aging(results[0], results[1])
        results.delete_at(0)
        results.delete_at(1)
        remaining_transition_days += days
      end

      if results.count.positive?
        remaining_transition_days += Job.find_aging(results[0], published_at)
        results.delete_at(0)
      end

      aging = last_transition_age.blank? ?
        remaining_transition_days :
        (remaining_transition_days + last_transition_age)

    elsif reason_to_reopen.blank? && closed
      aging = Job.find_aging(closed, published_at)
    else
      aging = Job.find_aging(Time.now, published_at)
    end
    aging.to_s.concat(' Days')
  end

  def job_status
    stage
  end
  
  def job_title
    title
  end

  def job_type
    type_of_job
  end

  def job_talent_suppliers
    picked_by.count
  end

  def account_manager_email
    account_manager.email rescue nil
  end

  def city_name
    city_obj['name']
  end
  
  def state_name
    state_obj['name']
  end
  
  def country_name
    country_obj['name']
  end

  def job_sourced
    tile_response(self, ['Sourced'])[0][:count]
  end
  
  def job_invited
    tile_response(self, ['Invited'])[0][:count]
  end
  
  def job_signed
    tile_response(self, ['Signed'])[0][:count]
  end
    
  def job_submitted
    tile_response(self, ['Submitted'])[0][:count]
  end
  
  def job_applied
    tile_response(self, ['Applied'])[0][:count]
  end
  
  def job_hired
    tile_response(self, ['Hired'])[0][:count]
  end

  def job_onboarding
    tile_response(self, ['On-boarding'])[0][:count]
  end

  def job_interviews
    tile_response(self, ['Interview'])[0][:count]
  end

  def job_disqualified
    tile_response(self, ['Disqualified'])[0][:count]
  end
end
