module Validations
  # ValidationsHiringOrganization
  module ValidationsHiringOrganization
    def self.included(receiver)
      receiver.class_eval do
        validates :company_relationship, presence: true, inclusion: {
          in: HiringOrganization::SRTYPE,
          allow_blank: true,
        }

        validates :company_relationship_name, presence: true,
                  uniqueness: { case_sensitive: false }

        validates :website, presence: true, on: :create

        validates :client, presence: true, if: proc { |obj| obj.direct? }
        validate :can_disable, on: :update
        validate :editable_name, on: :update
        validate :uniqueness_of_users
      end
    end

    ########################
    private
    ########################

    def editable_name
      return if confirmed_changed? && confirmed?
      return if changes['company_relationship_name'].blank? ||
        changes['company_relationship_name'][0] != 'Beeline'
      errors.add(:base, 'You are not allowed to edit name of this Hiring Organization.')
    end

    def can_disable
      return if billing_terms.enabled.empty? || enabled?
      return unless enable_changed?
      errors.add(:base, 'Disable all associated billing terms and try again.')
    end

    def uniqueness_of_users
      errors.add(:email, 'has already been taken') if users.map(&:email).uniq.size != users.size
    end
  end
end
