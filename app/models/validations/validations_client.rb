module Validations
  module ValidationsClient
    # include FilePathValidator
    def self.included(receiver)
      receiver.class_eval do
        validates :company_name,
                  :city, 
                  :country, 
                  :industry, 
                  :logo,
                  presence: true
        validates :state, :postal_code, presence: {if: proc { |c| ['US', 'CA'].include?(c.country)}}
        validates :company_name, uniqueness: { case_sensitive: false }
        validate :validate_country_state_and_city
        validate :can_disable?
        validate :check_account_manager, on: :create
        validate :check_supervisor, on: :create
        validate :editable_name, on: :update
      end
    end

    ########################
    private
    ########################

    def editable_name
      return unless changed.include?('company_name')
      beeline = HiringOrganization.beeline
      beeline_billing_term = beeline.billing_terms.where(client: self).count
      return if beeline_billing_term.zero?
      errors.add(:base, 'You are not allowed to edit name of this client.')
    end

    # clients having all disabled jobs can be disabled.
    def can_disable?
      return if changed.exclude?('active')
      if hiring_organizations.direct.enabled.any? || billing_terms.enabled.any?
        errors.add(:base, 'Disable all Direct hiring organizations and associated billing terms and try again')
      end
    end

    def check_account_manager
      return if assignables.select{|x| x.role == 'account_manager' and x.is_primary == true}.any?
      errors.add(:primary_account_manager, "can't be blank")
    end

    def check_supervisor
      return if assignables.select{|x| x.role == 'supervisor' and x.is_primary == true}.any?
      errors.add(:primary_supervisor, "can't be blank")
    end
  end
end
