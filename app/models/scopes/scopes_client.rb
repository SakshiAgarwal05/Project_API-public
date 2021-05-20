module Scopes
  module ScopesClient
    def self.included(receiver)
      receiver.class_eval do
        scope :visible_to, ->(user){
          return get_list_by_access(user.agency) if user.restrict_access
          return none unless user.all_permissions['clients']
          case user.all_permissions['clients']
          when 'all'
            where(nil)
          when 'assigned'
            return where(id: user.my_supervisord_client_ids) if user.supervisor?
            return where(id: user.my_managed_client_ids) if user.account_manager?
            return where(id: user.my_onboard_client_ids) if user.onboarding_agent?
          when 'public'
            where(active: true)
          else
            none
          end
        }

        scope :get_list_by_access, -> (agency) {
          where(id: agency.accessibles.distinct.pluck(:client_id))
        }

        scope :active, -> { where(active: true) }

        scope :my_clients, ->(user){
          return visible_to(user) if user.restrict_access
          return none unless user.all_permissions['my clients']
          case user.all_permissions['my clients']
          when 'all'
            all
          when 'assigned'
            return where(id: user.my_supervisord_client_ids) if user.supervisor?
            return where(id: user.my_managed_client_ids) if user.account_manager?
            return where(id: user.my_onboard_client_ids) if user.onboarding_agent?
          when 'saved by org'
            user.agency_user? ? by_agency_admin(user) : none
          when 'saved by team'
            user.agency_user? ? by_team_admin(user) : none
          when 'saved'
            user.agency_user? ? by_recruiter(user) : none
          else
            none
          end
        }

        scope :get_events_client, ->(events) {
          raise "Events not found in get_events_client" unless events
          joins(:events).where(id: events.select(:client_id).distinct).distinct
        }

        scope :get_clients_events_count, ->(events) {
          raise "Events not found in get_clients_events_count" unless events
          joins(:events).where(events: { id: events }).group(:id).count('events.id')
        }

        scope :by_agency_admin, -> (user) {
          active.includes(:saved_clients_users)
                .where(saved_clients_users: { user_id: user.my_agency_users.pluck(:id) })
        }

        scope :by_team_admin, ->(user) {
          active.includes(:saved_clients_users)
                .where(saved_clients_users: { user_id: user.my_team_users.pluck(:id) })
        }

        scope :by_recruiter, ->(user) { user.saved_clients.active }

        scope :my_job_clients, ->(user) { my_clients(user).active }

        scope :sortit, ->(order_field, order, current_user) {
          default_order = order || 'asc'
          order_field = order_field || 'created_at'
          case order_field
          when 'location'
            order("country_obj.name": order,
              "state_obj.name": order,
              "city": order
            )
          when 'if_saved'
            return order(updated_at: order || :desc) if current_user.internal_user?
            (order.eql?('asc') ? where(saved_by_ids: current_user.id) : where.not(saved_by_ids: current_user.id).order(:updated_at))
          when 'company_name'
            get_order("LOWER(clients.company_name)", default_order)
          when 'show_label'
            order(status: default_order)
          when 'cs_active_jobs_count'
            joins('left join jobs on jobs.client_id = clients.id').
              where({ jobs: { stage: Job::ACTIVE_STAGES, locked_at: nil, publish_to_cs: true } }).
              group('clients.id').
              get_order(Arel.sql("jobs.id").count, default_order)
          else
            order(order_field => default_order)
          end
        }
      end
    end
  end
end
