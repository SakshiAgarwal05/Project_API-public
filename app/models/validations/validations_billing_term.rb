module Validations
  # ValidationsBillingTerm
  module ValidationsBillingTerm
    def self.included(receiver)
      receiver.class_eval do
        validates :client, :categories, :countries, :hiring_organization, presence: true
        validates :billing_name, presence: true,
                  uniqueness: { case_sensitive: false, scope: [:type_of_job, :client, :hiring_organization] }

        validates :type_of_job, presence: true, inclusion: {
          in: BillingTerm::JOB_TYPES, allow_blank: true
        }

        validates :msp_available, inclusion: { in: [true, false] }

        validates :platform_type, presence: true, inclusion: {
          in: BillingTerm::PLATFORM_TYPES, allow_blank: true
        }

        validates :vms_platform, presence: { if: proc { |u| u.vms? } }
        validates :ats_platform, presence: { if: proc { |u| u.ats? } }
        validates :msp_name, presence: true,
                             if: proc { |u| u.msp_available? },
                             unless: proc { |u| u.msp_staffing? }

        validates :proprietary_platform, presence: true,
                                         if: proc { |u| u.proprietary_system? }

        validates :msp_vms_fee_rate, presence: true, numericality: {
          greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_blank: true
        }, if: proc { |u| u.msp_available? }

        validates :guarantee_period, presence: true, numericality: {
          greater_than_or_equal_to: 0, only_integer: true, allow_blank: true
        }

        validates :exclusivity_period, presence: true, numericality: {
          greater_than_or_equal_to: 0, only_integer: true, allow_blank: true
        }, if: proc { |obj| obj.full_time? }

        validates :billing_type, presence: true, inclusion: {
          in: billing_types, allow_blank: true
        }, if: proc { |obj| obj.contract? }

        validates :bill_markup, presence: true, if: proc { |obj| obj.markup? && obj.contract? }

        validates :crowdstaffing_payroll, inclusion: {
          in: [true, false]
        }, if: proc { |obj| obj.contract? }

        validates :crowdstaffing_margin, presence: true, if: proc { |obj| obj.strategic_staffing? }

        validate :can_disable?
        validate :guarantee_period_length
        validate :no_incumbent_agency_allowed
      end
    end

    ########################
    private
    ########################

    # clients having all disabled jobs can be disabled.
    def can_disable?
      active_candidats = jobs.includes(:talents_jobs).where(talents_jobs: { active: true })
      return if changed.exclude?('locked_at') || active_candidats.count.zero?
      errors.add(:base, I18n.t(
        'client.error_messages.cant_disable_active_job',
        company_name: billing_name,
        active_job_count: active_candidats.count
      ))
    end

    def guarantee_period_length
      return unless full_time? &&
                    guarantee_period_changed? &&
                    exclusivity_period_changed? &&
                    guarantee_period.to_i > exclusivity_period.to_i
      errors.add(:base,
                 'Guarantee period should be less than to exclusivity period')
    end

    def no_incumbent_agency_allowed
      return if agency_ids.nil? || id.nil?
      if Accessible.where(agency_id: agency_ids, billing_term_id: id, incumbent: true).any?
        errors.add(:base, 'Incumbent Agencies cannot be given exclusive access. Please remove them.')
      end
    end
  end
end
