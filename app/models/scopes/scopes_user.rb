module Scopes
  module ScopesUser
    def self.included(receiver)
      receiver.class_eval do
        [
          'super admin',
          'admin',
          'onboarding agent',
          'job sourcing agent',
          'account manager',
          'agency owner',
          'agency admin',
          'team admin',
          'team member',
          'talent sourcing agent',
          'supervisor',
          'finance agent',
          'client admin',
          'hiring mamager',
          'customer support agent',
        ].each do |role|
          method_name = role.tr(' ', '_').pluralize.to_sym
          scope method_name, -> { where(primary_role: role) }
        end

        scope :internal_members, -> { where(role_group: 1) }
        scope :agency_members, -> { where(role_group: 2) }
        scope :internal_members_except_ams, -> {
          where(role_group: 1).where.not(primary_role: 'account manager')
        }

        scope :hiring_members, -> { where(role_group: 3) }

        scope :for_hiring_org, -> (hiring_organization_id) {
          where(hiring_organization_id: hiring_organization_id)
        }

        scope :my_teams_users, -> (user) {
          where(
            id: TeamsUser.where(team_id: user.teams_users.select(:team_id)).select(:user_id)
          ).or(where(id: user.id))
        }
        # find list of users based on permissions assigned to current user.
        # Example: super admin can view all users. Agency admin can view only his company's users.
        scope :visible_to, ->(user) {
          return none unless user.is_a?(User) # rollbar#568
          return where(nil) if Role::COMMON_USED_ROLES.include?(user.primary_role)
          return where(agency_id: user.agency_id) if user.agency_owner_admin?
          if user.teams_users.present?
            return my_teams_users(user) if user.team_admin?
            return my_teams_users(user).team_members if user.team_member?
          elsif user.agency_user?
            return where(id: user.id)
          end
          return none
        }

        scope :get_events_user, -> (events_ar, role_group) {
          raise "events not found in get_events_user" unless events_ar
          joins("
            left outer join event_attendees on event_attendees.user_id = users.id
            left outer join events on events.id = event_attendees.event_id").
            where(events: { id: events_ar.select(:id) }, role_group: role_group).
            select("count(users.id) as events_counts, users.*").
            group(:id)
        }

        scope :invitable_for_event, ->(user) {
          if user.agency_id
            where(
              "primary_role in (?) OR agency_id = ?",
              ['account manager', 'supervisor', 'super admin', 'admin'],
              user.id
            )
          else
            visible_to(user)
          end
        }

        scope :users_according_to_visibility, ->(mentioned_ids, visibility) {
          case visibility
          when 'HO'
            User.where(id: mentioned_ids, role_group: [1, 2])
          when 'HO_AND_CROWDSTAFFING'
            User.where(id: mentioned_ids, role_group: [2])
          when 'HO_AND_CROWDSTAFFING_AND_TS'
            User.where(id: mentioned_ids).where.not(role_group: [1, 2, 3])
          when 'CROWDSTAFFING'
            User.where(id: mentioned_ids, role_group: [2, 3])
          when 'CROWDSTAFFING_AND_TS'
            User.where(id: mentioned_ids, role_group: [3])
          when 'TS'
            User.where(id: mentioned_ids, role_group: [1, 3])
          end
        }

        scope :event_listing_users, ->(user) {
          return none unless user.is_a?(User)
          case user.primary_role
          when 'super admin'
            where(
              primary_role: ['super admin', 'admin', 'supervisor', 'account manager']
            ).where.not(id: user.id)
          when 'admin'
            where(primary_role: ['admin', 'supervisor', 'account manager']).where.not(id: user.id)
          when 'supervisor'
            where(primary_role: ['supervisor', 'account manager']).where.not(id: user.id)
          when 'agency admin', 'agency owner'
            user.agency.users
          when 'team admin'
            user.my_team_users
          when 'team member', 'agency member'
            where(id: user.id)
          else
            none
          end
        }

        scope :with_editable_notes_by, ->(user) {
          roles = Role::GET_GROUP.keys
          return none unless user.is_a?(User)
          case user.primary_role
          when 'super admin', 'customer support agent'
            where(role_group: [1, 2])
          when 'admin'
            where(primary_role: roles - ['super admin']).where.not(role_group: 3)
          when 'supervisor'
            where(primary_role: ['supervisor', 'account manager', 'onboarding agent'])
          when 'enterprise owner', 'enterprise admin', 'enterprise manager', 'enterprise member'
            where(role_group: 3)
          when 'agency admin', 'agency owner'
            user.agency.users
          when 'team admin'
            user.my_team_users
          when 'account manager', 'onboarding agent', 'team member'
            where(id: user.id)
          else
            none
          end
        }

        scope :verified, -> { where.not(confirmed_at: nil).where(locked_at: nil) }
        scope :confirmed, -> { where.not(confirmed_at: nil) }

        # modify sortit_es too if you
        scope :sortit, ->(order_field, order) {
          default_order = order || 'desc'
          default_order_field = order_field || :created_at
          case order_field
          when 'location'
            order("country_obj.name": order,
                  "state_obj.name": order,
                  "city": order)
          # agency and invited - created for invited tab
          when 'agency'
            eager_load(:agency).
              get_order("agencies.company_name", default_order)
          when 'saved_at'
            includes(:recruiters_jobs).references(:recruiters_jobs).
              get_order("affiliates.updated_at", default_order)
          when 'invited_at'
            get_order("affiliates.created_at", default_order)
          when 'active_jobs_count'
            joins("
              LEFT OUTER JOIN affiliates ON
              affiliates.job_id = jobs.id AND
              affiliates.status in ('saved', 'archived')
              LEFT OUTER JOIN jobs on jobs.id = affiliates.job_id
            ").group('users.id').
              get_order(
                Arel.sql(
                  "case when jobs.stage not in ('Closed') then 1 ELSE null END"
                ).count, default_order
              )
          when 'score'
            select("users.*, COALESCE(sd_scores.score,0)::float as job_score").
              get_order(Arel.sql("COALESCE(sd_scores.score,0)::float"), default_order).
              order(first_name: :asc)
          when 'first_name'
            get_order("first_name", default_order)
          else
            order(default_order_field => default_order)
          end
        }

        scope :sortit_for_current_job, ->(order_field, order, job_id) {
          default_order = order || 'desc'
          default_order_field = order_field || 'users.created_at'
          case order_field
          when 'submitted', 'applied'
            joins('left join talents_jobs on talents_jobs.user_id = users.id').
              group('users.id').
              get_order(
                "count(case when talents_jobs.stage = '#{order_field.titleize}' and
                talents_jobs.job_id = '#{job_id}' then 1 ELSE null END)", default_order
              )
          when 'interviewed'
            fixed_stages = PipelineStep::FIXED_STAGES.map { |a| %Q('#{a}') }.join(", ")
            joins('left join talents_jobs on talents_jobs.user_id = users.id').
              group('users.id').
              get_order(
                "count(case when talents_jobs.stage not in (#{fixed_stages}) and
                talents_jobs.job_id = '#{job_id}' then 1 ELSE null END)", default_order
              )
          else
            order(default_order_field => default_order)
          end
        }

        # return talents jobs for active and saved jobs
        scope :saved_active_talents_jobs, -> {
          joins(recruiters_jobs: { job: :talents_jobs })
        }

        scope :sortit_for_active_jobs, ->(order_field, order) {
          default_order = order || 'desc'
          case order_field
          when 'submitted', 'applied'
            saved_active_talents_jobs.
              group('users.id').
              get_order(
                Arel.sql("case when talents_jobs.stage =
                '#{order_field.titleize}' then 1 ELSE null END").count,
                default_order
              )
          when 'interviewed'
            saved_active_talents_jobs.
              group('users.id').
              get_order(
                Arel.sql("case when talents_jobs.stage not in
                ('Sourced', 'Invited', 'Signed',
                'Submitted', 'Applied', 'Offer', 'Hired', 'On-boarding', 'Assignment Begins',
                'Assignment Ends') then 1 ELSE null END").count,
                default_order
              )
          end
        }

        scope :distributed_invited_restricted, -> {
          verified.
            includes(affiliates: :agency).
            where(
              affiliates: { responded: false, status: 'active' },
              agencies: { if_valid: true, locked_at: nil }
            ).
            where.not(affiliates: { type: 'RecruitersJob' })
        }

        scope :invited_distributed_restricted_jobs, -> (job) {
          distributed_invited_restricted.where(affiliates: { job_id: job.id })
        }

        scope :find_limited_users, -> (job) {
          verified.left_joins(:agency).where(
            agencies: {
              id: Accessible.where(
                client_id: job.client_id,
                billing_term_id: job.billing_term_id,
                hiring_organization_id: job.hiring_organization_id
              ).select(:agency_id),
              restrict_access: true,
            }
          )
        }

        scope :find_internal_users, -> (role, client_id, job_id) {
          case role
          when 'account manager'
            users = verified.account_managers
            client = client_id.present? ? Buyer.find(client_id) : nil
            users = users.where.not(id: client.account_managers.pluck(:user_id)) if client
            job = job_id.present? ? Job.find(job_id) : nil
            users = users.where(id: job.account_managers.pluck(:id)) if job
            users
          when 'onboarding agent'
            users = verified.onboarding_agents
            client = client_id.present? ? Buyer.find(client_id) : nil
            users = users.where.not(id: client.onboarding_agents.pluck(:user_id)) if client
            job = job_id.present? ? Job.find(job_id) : nil
            users = users.where(id: job.onboarding_agents.pluck(:id)) if job
            users
          when 'supervisor'
            users = verified.supervisors
            client = client_id.present? ? Buyer.find(client_id) : nil
            users = users.where.not(id: client.supervisors.pluck(:user_id)) if client
            job = job_id.present? ? Job.find(job_id) : nil
            users = users.where(id: job.supervisors.pluck(:id)) if job
            users
          else
            none
          end
        }

        scope :query_based_filtered_results, -> (query) {
          where("first_name ILIKE :query or
                last_name ILIKE :query or
                username ILIKE :query or
                email ILIKE :query",
                { query: '%' + query + '%' })
        }

        scope :event_internal_and_hiring_attendees, ->(active_job, user) {
          user_ids = []

          if user.agency_user?
            user_ids += active_job.picked_by.where(agency_id: user.agency_id)
            user_ids += active_job.internal_notifiers
          elsif user.internal_user?
            user_ids += active_job.notifiers
            user_ids += active_job.picked_by_ids
            user_ids += active_job.account_manager_ids
            user_ids += active_job.supervisor_ids
            user_ids += active_job.onboarding_agent_ids
            user_ids += active_job.client.assignables.select(:user_id)
            user_ids += active_job.all_ho_users(user).select(:id)
          elsif user.hiring_org_user?
            user_ids += active_job.internal_notifiers
            user_ids += active_job.all_ho_users(user).select(:id)
          end

          verified.where(
            "primary_role in ('super admin', 'admin', 'customer support agent')
              or users.id in (?)", user_ids.flatten.compact.uniq
          )
        }

        scope :enterprise_visibility, -> (user) {
          ho_users = user.all_permissions['actions hiring organizations users']
          if ho_users
            where(role_group: 3)
          elsif user.enterprise_owner? || user.enterprise_admin? || user.groups_users.empty?
            where(hiring_organization_id: user.hiring_organization_id)
          else
            where(
              hiring_organization_id: user.hiring_organization_id,
              id: GroupsUser.where(group_id: user.group_ids).select(:user_id)
            )
          end
        }

        scope :get_team_admin, ->(user) {
          joins(:teams).where(primary_role: 'team admin', teams: { id: user.team_ids })
        }

        scope :message_valid_users, ->(user) {
          active_users = where(locked_at: nil)

          if user.internal_user?
            active_users.where(role_group: [1, 2, 3])
          elsif user.agency_user?
            agency_id = user.agency_id

            active_users = active_users.where(role_group: 1).
              or(active_users.where(role_group: 2, agency_id: agency_id))

            if user.limited_access?
              ho_ids = Accessible.where(agency_id: agency_id, incumbent: true).
                select(:hiring_organization_id).distinct

              active_users =
                if ho_ids.any?
                  active_users.
                    or(where(role_group: 3, hiring_organization_id: ho_ids, locked_at: nil))
                else
                  active_users
                end
            end
            active_users
          elsif user.hiring_org_user?
            ho_id = user.hiring_organization_id

            active_users = where(role_group: 1).
              or(active_users.where(role_group: 3, hiring_organization_id: ho_id))

            agency_ids = Accessible.where(hiring_organization_id: ho_id, incumbent: true).
              select(:agency_id).distinct

            active_users =
              if agency_ids.any?
                active_users.or(where(role_group: 2, agency_id: agency_ids, locked_at: nil))
              else
                active_users
              end
            active_users
          else
            none
          end
        }
      end
    end
  end
end
