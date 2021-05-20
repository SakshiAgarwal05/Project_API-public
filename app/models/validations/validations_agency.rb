module Validations
  module ValidationsAgency
    def self.included(receiver)
      receiver.class_eval do
        validates :company_name, :website, :login_url, presence: true
        validates :city,
                  :state,
                  :country,
                  :postal_code,
                  :contact_number,
                  presence: true,
                  if: :if_valid?

        validates :company_name, :login_url, uniqueness: { case_sensitive: false }

        validates :website,
                  uniqueness: { case_sensitive: false },
                  if: proc { |agency|
                    agency.website &&
                    agency.website.downcase.match(/crowdstaffing/).blank?
                  },
                  allow_blank: true

        validates :login_url,
          format:  /\A^(?:[-\w]+\.)+crowdstaffing\.com$\z/,
          allow_blank: true,
          length: {maximum: 253, minimum: 2} # http standard

        validate :blocked_domains
        validate :validate_country_state_and_city, on: :update
        validate :presence_of_agency_owner
        validate :presence_of_accessibles
        validate :uniqueness_of_users
        validate :check_exclusivity_before_restricting, on: :update
      end
    end

    ########################

    private

    ########################

    def blocked_domains
      return unless website
      prefix = website.include?('http') ? "" : "http://"
      host = URI.parse(prefix + website).host
      domain = PublicSuffix.parse(host).sld
      return unless Agency::BLOCKED_DOMAINS.include?(domain)
      errors.add(:website, 'is not valid')
    end

    def presence_of_accessibles
      return true if !restrict_access || accessibles.size > 0

      errors.add(:base, 'You must select at least 1 Client/Hiring Organization/Billing term')
    end

    def check_exclusivity_before_restricting
      return unless changed.include?('restrict_access') || restrict_access
      bt_ids = accessibles.collect{ |accessible| accessible&.billing_term_id if accessible.incumbent }.flatten.compact.uniq
      return unless bt_ids.any?
      exclusive_agencies =
        ActiveRecord::Base.connection.execute("
          SELECT agency_id FROM agencies_billing_terms where billing_term_id in
            (#{bt_ids.collect{|bt_id| "'"+bt_id+"'"}.join(',')})"
        ).values.flatten.compact.uniq

      return unless exclusive_agencies.include?(id)
      errors.add(:base, 'You cannot make this agency incumbent as it is added in some billing term. Please remove from there.')
    end

    # at least one agency owner is required for creating an agency
    def presence_of_agency_owner
      return if (users.collect(&:primary_role) & ['agency owner', 'agency admin']).any?
      errors.add(:base, "agency owner or admin can't be blank.")
    end

    def on_update?
      persisted? && is_owner?
    end

    def uniqueness_of_users
      errors.add(:email, 'has already been taken') if users.map(&:email).uniq.size != users.size
    end
  end
end
