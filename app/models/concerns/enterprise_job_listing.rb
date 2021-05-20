module Concerns::EnterpriseJobListing
  extend ActiveSupport::Concern
  include Enterprise::JobsHelper


  def published_date
    published_at&.strftime("%m/%d/%Y")
  end

  def client_name
    client.company_name
  end

  def job_status
    stage
  end

  def enterprise_sourced
    job_tile_response(self, ['Sourced'], hiring_organization)[0][:count]
  end

  def enterprise_invited
    job_tile_response(self, ['Invited'], hiring_organization)[0][:count]
  end

  def enterprise_submitted
    job_tile_response(self, ['Submitted'], hiring_organization)[0][:count]
  end

  def enterprise_applied
    job_tile_response(self, ['Applied'], hiring_organization)[0][:count]
  end

  def enterprise_hired
    job_tile_response(self, ['Hired'], hiring_organization)[0][:count]
  end

  def enterprise_interviews
    job_tile_response(self, ['Interview'], hiring_organization)[0][:count]
  end

  def enterprise_disqualified
    job_tile_response(self, ['Disqualified'], hiring_organization)[0][:count]
  end
end
