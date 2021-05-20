module Concerns::ActiveCandidatesListingValues
  extend ActiveSupport::Concern
  include ActionView::Helpers::DateHelper

  def candidate_name
    talent&.name
  end

  def candidate_email
    talent&.email
  end

  def qualified_or_disqualified
    rejected ? 'Disqualified' : 'Qualified'
  end

  def last_action
    time_ago_in_words(updated_at)
  end

  def name_of_client
    job&.client&.company_name
  end

  def job_title
    job&.title
  end

  def id_of_job
    job&.job_id
  end

  def positions
    job&.positions
  end

  def published_date
    job&.published_at&.strftime("%m/%d/%Y")
  end

  def job_status
    job&.stage
  end

  def talent_supplier_name
    user&.internal_user? ? nil : user&.name
  end

  def talent_supplier_email
    user&.internal_user? ? nil : user&.email
  end

  def supplier_agency_name
    user&.internal_user? ? nil : user&.agency&.company_name
  end
end
