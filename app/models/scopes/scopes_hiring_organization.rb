module Scopes
  # ScopesHiringOrganization
  module ScopesHiringOrganization
    def self.included(receiver)
      receiver.class_eval do
        scope :direct, -> { where(company_relationship: 'Direct') }
        scope :msp, -> { where(company_relationship: 'MSP') }
        scope :strategic_partners, -> { where(company_relationship: 'Strategic Partner') }
        scope :enabled, -> { where(locked_at: nil) }
        scope :disabled, -> { where.not(locked_at: nil) }

        scope :sortit, ->(order_field, order) {
          default_order = order.presence || 'desc'
          default_order_field = order_field.presence || 'created_at'
          case order_field
          when 'members'
            joins(
              "left outer join users on users.hiring_organization_id = hiring_organizations.id
                and confirmed_at is not NULL
                and locked_at is null"
            ).select(
              "hiring_organizations.*, count(users.id)"
            ).group("hiring_organizations.id").get_order("COUNT(users.id)", order)
          when 'website'
            order("regexp_replace(website, '^(https?://)?(www\.)?', '') #{default_order}")
          else
            order(default_order_field => default_order)
          end
        }
      end
    end
  end
end
