module Scopes
  module ScopesTeam
    def self.included(receiver)
      receiver.class_eval do
        # find list of teams a user can view.
        #
        # Example
        # * All teams for internal users
        # * agency's team for agency admin
        # * assigned team of team_member
        scope :for_user, ->(user) {
          return where(nil) if user.all_permissions['actions teams']
          if user.all_permissions['actions own teams'] && user.agency_owner_admin?
            return user.agency.teams
          else
            return user.teams
          end
          return none
        }

        scope :sortit, -> (order_field, order) {
          default_order = order || 'desc'
          default_order_field = order_field || 'created_at'
          case order_field
          when 'name'
            get_order("LOWER(name)", default_order)
          when 'active_recruiters_count'
            left_outer_joins(:users).
              where("(users.confirmed_at is not NULL AND users.locked_at is NULL) OR (users.id is NULL)").
              group(:id).get_order(Arel.sql("users.id").count, order)
          else
            order(default_order_field => default_order)
          end
        }
      end
    end

    ########################

    private

    ########################
  end
end
