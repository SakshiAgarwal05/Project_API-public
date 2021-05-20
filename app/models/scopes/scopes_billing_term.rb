module Scopes
  # ScopesBillingTerm
  module ScopesBillingTerm
    def self.included(receiver)
      receiver.class_eval do
        scope :sortit, ->(order_field, order) {
          default_order = order.presence || 'desc'
          default_order_field = order_field.presence || 'created_at'
          case order_field
          when 'company_relationship_name'
            eager_load(:hiring_organization).
              select("billing_terms.*, hiring_organizations.company_relationship_name").
              get_order(
                Arel.sql("hiring_organizations.company_relationship_name"),
                default_order
              )
          else
            order(default_order_field => default_order)
          end
        }

        scope :enabled, -> { where(locked_at: nil) }
        scope :disabled, -> { where.not(locked_at: nil) }
        scope :for_client, -> (client_id) { where(client_id: client_id) }
      end
    end
  end
end
