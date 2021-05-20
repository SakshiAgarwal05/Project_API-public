module Validations
  module ValidationsUser
    def self.included(receiver)
      receiver.class_eval do
        validates :primary_role, presence: true,
                  inclusion: { in: Role::GET_GROUP.keys }

        validate :add_detailed_errors, on: :create, if: :not_system
        # validates :first_name, :last_name, presence: { if: -> u { u.valid_user? && u.not_system } }

        validates :agency, presence: { if: proc { |u| u.role_group.eql?(2) } }

        validates :created_by,
                  presence: {
                    if: proc { |u|
                      !['super admin', 'system'].include?(u.primary_role) && !u.persisted?
                      [1, 2].include?(u.role_group)
                    }
                  }, allow_blank: true

        validates :contact_no,
                  presence: true,
                  if: Proc.new { |u|
                    u.try(:onboarding_agent?) ||
                    u.try(:account_manager?) ||
                    u.try(:supervisor?) ||
                    u.try(:customer_support_agent?)
                  }

        validates :contact_no, format: /\A^[\+]?(\d\-?){3,12}\d$\z/, allow_blank: true

        validates :skills, validate_maximum_limit: { limit: 50 }
        validates :categories, validate_maximum_limit: { limit: 20 }
        validates :industries, validate_maximum_limit: { limit: 5 }
        validates :countries, validate_maximum_limit: { limit: 4 }
        validates :email_signature, length: { maximum: 10000 }

        validate :business_email
        validate :check_clients, on: :update
        validate :confirmation_of_agency_owner, :check_agency_disabled?, on: :create
        validate :presence_of_phone, if: :confirming?
        validate :validate_password
        validate :reset_password_when_disabled, on: :update
        validate :check_assigned_jobs
        validate :check_before_creating_ho_member
      end
    end

    def not_system
      primary_role != 'system'
    end

    def valid_user?
      (internal_user? && !account_manager?) || confirmed? && agency_user? && agency
    end

    ########################

    private

    ########################

    def presence_of_phone
      errors.add(:base, "Phone number can't be blank") if contact_no.blank? && phones.empty?
    end

    def business_email
      return unless email

      if agency
        to_match = get_domain_match(agency.website)
        return if email.match(/@(#{to_match})$/i)
        errors.add(:email, "should match with website domain")
      elsif hiring_organization.present?
        to_match = get_domain_match(hiring_organization.website)
        return if email.match(/@(#{to_match})$/i)
        errors.add(:email, "should match with website domain")
      else
        to_match = "crowdstaffing.com"
        return if email.match(/@(#{to_match})$/i)
        errors.add(:email, "should be crowdstaffing email address")
      end
    end

    def confirmation_of_agency_owner
      return if !agency_user? || !agency || agency.new_record? || agency.owner.confirmed?

      errors.add(:base, 'Agency Owner is yet not confirmed')
    end

    def check_agency_disabled?
      errors.add(:base, 'Agency is disabled') if agency && agency.status.eql?('Disabled')
    end

    def confirming?
      return false if primary_role == 'system' || changed.include?("confirmed_at")
      confirmed?
    end

    def valid_recruiter_profile?
      confirming? && agency_user? && agency
    end

    def address_on_confirm
      changed.include?('confirmed_at') && changed != ["encrypted_password"]
    end

    def reset_password_when_disabled
      return unless changed.include?('encrypted_password')
      if (hiring_org_user? && hiring_organization && !hiring_organization.enable) || (agency_user? && agency && !agency.enabled)
        errors.add(:base, 'Reset password token is invalid')
      end
    end

    def check_clients
      return true unless confirmed? && (changes['show_status'] == ['Active', 'Disabled'])

      return true unless
        (supervisor? && my_supervisord_client_ids.any?) ||
        (account_manager? && my_managed_client_ids.any?)

      errors.add(:base, 'Some clients still assigned to this user.')
    end

    def check_assigned_jobs
      return if locked_at.nil?
      return unless
        (account_manager? && managed_jobs.exists?) ||
        (supervisor? && supervisord_jobs.exists?) ||
        (onboarding_agent? && onboard_jobs.exists?)

      errors.add(:base, 'Please re-assign jobs to other user before disabling.')
    end

    def find_domain(website)
      prefix = website.include?('http') ? "" : "http://"
      host = URI.parse(prefix + website).host.sub('www.', '')
      PublicSuffix.parse(host)
    end

    def get_domain_match(website)
      domain = find_domain(website)
      "#{domain.domain}|#{domain.subdomain}|crowdstaffing.com"
    end

    def domain_match_for_ho_and_agency_attendee(website)
      domain = find_domain(website)
      "#{domain.domain}|#{domain.subdomain}"
    end

    def check_before_creating_ho_member
      return if hiring_org_user? && hiring_org_owner
      return if !hiring_organization ||
        hiring_organization.new_record? ||
        (hiring_organization.owner && hiring_organization.owner.confirmed?)

      errors.add(:base, 'Hiring Organization Owner is yet not confirmed')
    end
  end
end
