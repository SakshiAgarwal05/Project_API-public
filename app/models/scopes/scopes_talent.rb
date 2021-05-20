module Scopes
  module ScopesTalent

    def self.included(receiver)
      receiver.class_eval do
        scope :complete, -> { where(if_completed: true) }
        scope :disabled, -> { where.not(locked_at: nil) }
        scope :enabled, -> { where(locked_at: nil) }

        # update visible_to_es if you change this function
        scope :visible_to, ->(user) {
          user.all_permissions['actions candidate pool'] ? where(nil) : none
        }

        scope :my_talents, ->(user) {
          my_candidates = user.all_permissions['my candidates']
          return unless my_candidates || my_candidates&.blank?

          joins(:profiles).
            where(profiles: {
              agency_id: user.agency_id,
              hiring_organization_id: user.hiring_organization_id,
              profilable_type: 'User',
              my_candidate: true,
            })
        }

        scope :my_created_talents, ->(user) {
          my_talents(user).where(profilable_id: user.id)
        }

        scope :sortit, ->(order_field, order, current_user, profile) {
          default_order = order || 'asc'
          table_name = 'talents'
          result = self
          if profile
            table_name = 'profiles'
          end
          case order_field
          when 'location'
            get_order(Arel.sql("
              #{table_name}.country_obj->>'name',
              #{table_name}.state_obj->>'name',
              #{table_name}.city
            "), default_order)
          when 'first_name'
            get_order(
              Arel.sql("LOWER(#{table_name}.first_name)"),
              default_order
            )
          when 'years_of_experience'
            get_order(
              Arel.sql("CAST(
                CONCAT(
                  #{table_name}.years_of_experience->>'years',
                  '.',
                  ABS(CAST(#{table_name}.years_of_experience->>'months' as integer))
                  ) as float)"),
              default_order
            )
          when 'active_jobs_count'
            left_outer_join("left join talents_jobs on
              talents_jobs.talent_id = talents.id and
              talents_jobs.active = true").
              get_order(Arel.sql("count(talents_jobs)"), default_order)
          when 'verified'
            get_order(Arel.sql("talents.confirmed_at"), default_order)
          when 'created'
            get_order(Arel.sql("#{table_name}.created_at"), default_order)
          else
            get_order(Arel.sql("#{table_name}.#{order_field}"), default_order)
          end
        }

        scope :query_based_filtered_results, ->(query) {
          where(
            "talents.first_name ilike :query or
              talents.last_name ilike :query or
              talents.email ilike :query",
              {query: '%' + query + '%'}
          )
        }

        scope :event_talent_attendees, ->(active_job, user){
          result = joins(:talents_jobs).
            where("talents_jobs.job_id = '#{active_job.id}' and
            talents_jobs.withdrawn = false")

          if user.all_permissions['actions candidate pool']
            result.visible_to(user)
          else
            if user.hiring_org_user?
              result.where(
                "talents.id in (?) OR (rejected = false and sort_order >= ?)",
                my_talents(user).select(:id),
                1.5
              )
            elsif user.agency_user?
              result.my_talents(user)
            end
          end
        }
      end
    end
  end
end
