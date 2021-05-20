module Scopes
  module ScopesAgency
    def self.included(receiver)
      receiver.class_eval do
        scope :sortit, -> (order_field, order) {
          default_order = order || 'desc'
          default_order_field = order_field || 'created_at'
          case order_field
          when 'company_name'
            get_order("LOWER(company_name)", default_order)
          when 'expertise_category1'
            get_order("LOWER(expertise_category1)", default_order)
          when 'expertise_category2'
            get_order("LOWER(expertise_category2)", default_order)
          when 'expertise_category3'
            get_order("LOWER(expertise_category3)", default_order)
          when 'active_jobs_count'
            order(active_jobs: order)
          when 'users_count'
            left_joins(:users).group(:id).get_order("COUNT(users.id)", order)
          when 'active_recruiters_count'
            left_outer_joins(:users).
              where("(users.confirmed_at is not NULL AND users.locked_at is NULL) OR (users.id is NULL)").
              group(:id).get_order("COUNT(users.id)", order)
          when 'last_seen'
            left_joins(:users).
              select("agencies.*, MAX(users.current_sign_in_at) as current_sign_in_at").
              group(:id).
              get_order(Arel.sql("MAX(case when users.current_sign_in_at is null then '2014-06-01 00:00' else users.current_sign_in_at end)"), order)
          when 'joined_at'
            left_joins(:users).
              where({ users: { primary_role: 'agency owner' } }).
              select('agencies.*, users.confirmed_at as joined_at').
              get_order("joined_at", order)
          when 'website'
            get_order("REPLACE(LOWER(website), 'www', '')", default_order)
          else
            order(default_order_field => default_order)
          end
        }

        scope :active, -> { where(if_valid: true, locked_at: nil) }
      end
    end

    ########################
    private
    ########################

  end
end
