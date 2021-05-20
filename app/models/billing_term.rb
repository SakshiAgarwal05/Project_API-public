# BillingTerm
class BillingTerm < ApplicationRecord
  acts_as_paranoid
  include AddEnableField
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include AddAbility
  include Constants::ConstantsBillingTerm
  include Fields::FieldsBillingTerm
  include Validations::ValidationsBillingTerm
  include ModelCallback::CallbacksBillingTerm
  include Scopes::ScopesBillingTerm
  include ES::ESBillingTerm

  def ats?
    platform_type.eql? 'Applicant Tracking System'
  end

  def vms?
    platform_type.eql? 'VMS'
  end

  def proprietary_system?
    platform_type.eql? 'Proprietary System'
  end

  def direct_staffing?
    hiring_organization&.direct?
  end

  def strategic_staffing?
    hiring_organization&.strategic_partner?
  end

  def msp_staffing?
    hiring_organization&.msp?
  end

  def full_time?
    type_of_job.eql?('Full Time')
  end

  def contract?
    type_of_job.eql?('Contract')
  end

  def active_jobs
    jobs.active_jobs.for_adminapp
  end

  def states_for(country)
    states.where(country_id: country&.id)
  end

  def is_incumbent?(agency)
    agency.accessibles.incumbents.where(billing_term_id: id).exists?
  end

  def recruiters_for(agency)
    agency.users.joins(recruiters_jobs: :job).
      where(
        affiliates: { status: ['saved', 'archived'] },
        jobs: { billing_term_id: id }
      )
  end
end
