module Scopes
  # ScopesShareable
  module ScopesShareable
    def self.included(receiver)
      receiver.class_eval do
        scope :shared_talents, -> { where.not(talent_id: nil) }

        scope :unacknowledged_applicants, -> (user_id) { where(user_id: user_id, acknowledged: false).shared_talents }

        scope :active, -> { where(status: %w(New Sourced Saved)) }

        scope :visible_to, -> (login_user) {
          return none unless login_user.is_a?(User)
          if Role::COMMON_USED_ROLES.include?(login_user.primary_role)
            return where(nil)
          elsif login_user.agency_user? && login_user.agency.present?
            return where(user_id: login_user.agency.user_ids)
          elsif login_user.hiring_org_user?
            return where(user_id: login_user.hiring_organization.user_ids)
          else
            return none
          end
        }

        scope :sortit, -> (order_field, order) {
          default_order = order.presence || 'desc'
          default_order_field = order_field.presence || 'created_at'
          case order_field
          when 'first_name'
            eager_load(:talent).
              select("shareables.*, talents.first_name").
              get_order(
                Arel.sql("talents.first_name"),
                default_order
              )
          when 'owner.name'
            eager_load(:user).
              select("shareables.*, users.first_name").
              get_order(
                Arel.sql("users.first_name"),
                default_order
              )
          when 'source'
            order(referrer: default_order)
          when 'status'
            order(status: default_order)
          else
            order(default_order_field => default_order)
          end
        }

        scope :by_period, -> (time_period) {
          case time_period
          when 'today'
            where(created_at: THIS_DAY)
          when 'this_week'
            where(created_at: THIS_WEEK)
          when 'this_month'
            where(created_at: THIS_MONTH)
          when 'this_year'
            where(created_at: THIS_YEAR)
          else
            all
          end
        }
      end
    end
  end
end
