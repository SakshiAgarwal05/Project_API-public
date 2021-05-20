module Scopes
  module ScopesJob
    def self.included(receiver)
      receiver.class_eval do
        scope :new_jobs, -> {
          where("jobs.published_at >= ? AND stage = ?", 7.days.ago, Job::OPEN_STATUS)
        }

        scope :enabled, -> {
          joins(:client).where(locked_at: nil).where.not(stage: 'Draft')
        }

        scope :default_order, -> { order(published_at: :desc) }

        scope :complete_valid_jobs, -> { enabled.published }

        scope :published, -> { where("jobs.published_at < ?", Time.now) }

        scope :draft, -> { where(stage: 'Draft') }

        scope :open_jobs, -> { complete_valid_jobs.where(stage: Job::OPEN_STATUS) }

        scope :closed_jobs, -> { where(stage: 'Closed') }

        scope :public_jobs, -> { open_jobs.default_order.only_public }

        scope :placed_jobs, -> {
          joins(:metrics_stages).where(metrics_stages: { stage: 'Assignment Begins' })
        }

        scope :published_to_cs, -> {
          open_jobs.default_order.only_published_to_cs
        }

        scope :published_to_cs_including_onhold, -> {
          active_jobs.order(created_at: :desc).only_published_to_cs
        }

        scope :active_jobs, -> {
          published.where(stage: Job::STAGES_FOR_APPLICATION, locked_at: nil)
        }

        scope :for_adminapp, -> { where(visible_to_cs: true) }
        scope :ho_internal_use, -> { where(visible_to_cs: false) }

        # default_scope -> {}
        scope :only_public, -> { where(is_private: false) }
        scope :only_published_to_cs, -> { where(publish_to_cs: true) }

        # modify visible_to_es too if you change this

        scope :can_view_only, ->(user) { visible_to(user) }

        # modify job > visible_to(user) if there is change in logic
        scope :visible_to, ->(user) {
          return none unless user.all_permissions['jobs']
          case user.all_permissions['jobs']
          when 'all'
            for_adminapp

          when 'assigned clients'
            if user.supervisor?
              return for_adminapp.where(client_id: user.my_supervisord_client_ids)
            end

            if user.account_manager?
              return for_adminapp.where(client_id: user.my_managed_client_ids)
            end

            if user.onboarding_agent?
              return for_adminapp.where(client_id: user.my_onboard_client_ids)
            end

            none

          when 'assigned jobs'
            return for_adminapp.where(supervisor_id: user.id) if user.supervisor?

            if user.account_manager?
              return for_adminapp.where(account_manager_id: user.id)
            end

            if user.onboarding_agent?
              return for_adminapp.where(onboarding_agent_id: user.id)
            end

            none

          when 'published'
            if user.agency_user?
              return none unless user.restrict_access || user.tnc

              if user.restrict_access
                return for_adminapp.
                    where.not(stage: Job::INACTIVE_STAGES).get_list_by_access(user)
              else
                return for_adminapp.
                    where.not(stage: Job::INACTIVE_STAGES).invited_distributes_jobs(user)
              end
            else
              for_adminapp.
                where("jobs.published_at < ? AND jobs.is_private = false", Time.now)
            end
          else
            none
          end
        }

        scope :get_events_jobs, ->(events) {
          raise "Events not found in get_events_jobs" unless events
          joins(:events).where(events: { id: events.select(:id) }).distinct
        }

        scope :get_jobs_events_count, ->(events) {
          raise "Events not found in get_jobs_events_count" unless events
          joins(:events).where(events: { id: events }).group(:id).count('events.id')
        }

        scope :invited_distributes_jobs, -> (user) {
          if user.agency_user?
            special_job_ids = Affiliate.joins(:job).where(
              "jobs.exclusive_access_end_time > ? AND
              user_id = ? AND
              type = ? OR
              (
                agency_id = ? AND type IN (?)
              )",
              Time.now,
              user.id,
              'ExclusiveJob',
              user.agency_id,
              ['Distribution', 'Invitation']
            ).select(:job_id).distinct

            where(is_private: false).
              where("exclusive_access_end_time IS NULL OR exclusive_access_end_time < ?",
                    Time.now.utc).
              or(Job.where(id: special_job_ids))
          else
            left_outer_joins(:agencies, :affiliates).
              where(
                "jobs.is_private = false OR
                (jobs.is_private = true AND
                  (agencies.id = :agency_id OR
                    (
                      affiliates.agency_id = :agency_id AND
                      affiliates.type in ('Distribution', 'Invitation')
                    )
                  )
                )",
                { agency_id: user.agency_id }
              ).distinct
          end
        }

        # modify my_jobs_es too if you change this
        # modify job > if_my_job(user) if there is change in logic
        scope :my_jobs, -> (user) {
          return none unless user.all_permissions['my jobs']
          case user.all_permissions['my jobs']
          when 'all'
            for_adminapp
          when 'assigned clients'
            if user.supervisor?
              return for_adminapp.where(client_id: user.my_supervisord_client_subquery)
            end

            if user.account_manager?
              return for_adminapp.where(client_id: user.my_managed_client_subquery)
            end

            if user.onboarding_agent?
              return for_adminapp.where(client_id: user.my_onboard_client_subquery)
            end

            none

          when 'assigned jobs'
            return for_adminapp.where(supervisor_id: user.id) if user.supervisor?
            return for_adminapp.where(account_manager_id: user.id) if user.account_manager?
            return for_adminapp.where(onboarding_agent_id: user.id) if user.onboarding_agent?
            none

          when 'assigned hiring organizations'
            if user.enterprise_owner? || user.enterprise_admin?
              where(hiring_organization_id: user.hiring_organization_id)
            else
              by_hiring_manager(user)
            end
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

        scope :get_list_by_access, -> (user) {
          t = %w(Invitation ExclusiveJob RecruitersJob Distribution)
          t << 'AccessibleJob' if user.restrict_access

          for_adminapp.joins(:affiliates).
            where(affiliates: { type: t, user: user }).
            distinct
        }

        scope :by_agency_admin, -> (user) {
          for_adminapp.where(
            id: user.agency.affiliates.saved.select(:job_id)
          )
        }

        scope :by_team_admin, ->(user) {
          team_user_ids = user.agency.affiliates.saved.where(
            user_id: user.my_team_users.select(:id)
          )

          for_adminapp.where(id: team_user_ids.select(:job_id))
        }

        scope :by_recruiter, ->(user) {
          for_adminapp.
            where(
              id: user.agency.affiliates.saved.where(user_id: user.id).select(:job_id)
            )
        }

        scope :by_hiring_manager, -> (user) {
          if user.groups.exists?
            user_ids = GroupsUser.where(group_id: user.group_ids).select(:user_id)
            where(hiring_manager_id: user_ids).
              or(Job.where(id: HoJobsWatcher.where(user_id: user_ids).select(:job_id)))
          else
            where(hiring_organization_id: user.hiring_organization_id)
          end
        }

        scope :by_hiring_member, -> (user) { by_hiring_manager(user) }

        scope :saved_by_me, ->(user) {
          return none if user.is_a?(Talent)
          return my_jobs(user).where(nil) if user.super_admin? || user.admin?
          return my_jobs(user).where(supervisor_id: user.id) if user.supervisor?
          return my_jobs(user).where(account_manager_id: user.id) if user.account_manager?
          return my_jobs(user).where(onboarding_agent_id: user.id) if user.onboarding_agent?
          return my_jobs(user).where(id: user.job_ids) if user.agency_user?
        }

        scope :inactive, -> { where(stage: Job::STAGES_FOR_CLOSED) }

        scope :picked_by, -> (users) {
          ids = users.is_a?(User) ? users.id : users.select(:id)
          joins(:affiliates).
            where(affiliates: { user_id: ids, status: 'saved' }).
            distinct
        }

        # modify sortit_es too if you
        scope :sortit, ->(order_field, order, current_user) {
          default_order = order || 'asc'
          if (order_field == 'saved_at' && current_user.role_group != 2) ||
            order_field.nil? || order_field == 'score'
            order_field = 'published_at'
          end
          case order_field
          when 'location'
            order("country_obj.name": order,
                  "state_obj.name": order,
                  "city": order)
          when 'saved_at'
            includes(:affiliates).order("affiliates.updated_at #{default_order}")
          when 'published_at'
            select('jobs.*, (case when jobs.published_at is NULL then jobs.created_at ELSE jobs.published_at end)').
              get_order("(case when jobs.published_at is NULL then jobs.created_at ELSE jobs.published_at end)", order)
          when 'stage'
            order("priority_of_status" => default_order)
          when 'recruiters', 'active_recruiters_count', 'recruiters_count'
            recruiters_count_sorting(default_order)
          when 'disqualified'
            disqualified_count_sorting(current_user, default_order)
          when 'submitted', 'applied', 'sourced', 'invited', 'offer', 'hired'
            stage_count_sorting(current_user, default_order, order_field)
          when 'interview'
            interview_stage_count_sorting(current_user, default_order)
          when 'invited_at'
            order(published_at: default_order)
          when 'salary', 'suggested_pay_rate'
            order(suggested_pay_rate: default_order)
          when 'applicants'
            left_joins(:shareables).group(:id).get_order("COUNT(shareables.talent_id)", order)
          when 'clicks'
            left_joins(:share_links).group(:id).get_order("SUM(share_links.clicks)", order)
          when 'unique_views'
            left_joins(:share_links).group(:id).get_order("SUM(share_links.visits)", order)
          when 'unique_links'
            left_joins(:share_links).group(:id).get_order("COUNT(share_links.id)", order)
          when 'recommended'
            if current_user.agency_user? && ["development", "test"].exclude?(Rails.env)
              joins("
                LEFT OUTER JOIN shared.csmm_scores ON
                  csmm_scores.job_id = jobs.id AND csmm_scores.user_id = '#{current_user.id}'
              ").
                left_joins(:probability_of_hire_stat).
                order("csmm_scores.score desc NULLS LAST").
                order("probability_of_hire desc NULLS LAST")
            else
              order(published_at: default_order)
            end
          when 'poh_score'
            if current_user.internal_user? && ["development", "test"].exclude?(Rails.env)
              left_joins(:static_poh).order("estimated_poh #{default_order}")
            end
          when 'popular'
            if current_user.internal_user? || current_user.hiring_org_user?
              order(popularity: :desc)
            end
          else
            order(order_field => default_order)
          end
        }

        scope :poh_csmm_score_sort, -> (order_field, current_user, options = {}) {
          poh_field = "probability_of_hire"
          csmm_score_field = "csmm_scores.score"
          if options[:aggregate].present?
            poh_field = "SUM(#{poh_field})"
            csmm_score_field = "SUM(#{csmm_score_field})"
          end

          if current_user.internal_user? || current_user.hiring_org_user?
            left_joins(:probability_of_hire_stats).order("#{poh_field} desc NULLS LAST")
          else
            joins("
              LEFT OUTER JOIN shared.csmm_scores ON
                csmm_scores.job_id = jobs.id AND csmm_scores.user_id = '#{current_user.id}'
            ").
              left_joins(:probability_of_hire_stat).
              order("#{csmm_score_field} desc NULLS LAST").
              order("#{poh_field} desc NULLS LAST").
              select(csmm_score_field, poh_field)
          end
        }

        scope :active_recommend_for, -> (user) {
          joins("
            LEFT JOIN affiliates d1 on
              d1.type='Distribution' and
              d1.job_id = jobs.id and
              d1.responded = false and
              d1.status = 'active'
          ").
          where(d1: { user_id: user.id }).distinct
        }

        scope :invited_jobs_for, -> (user) {
          if user.restrict_access
            # visible_to(user)
            open_jobs.
              joins("
                LEFT OUTER JOIN affiliates as invites ON
                invites.job_id = jobs.id AND
                invites.type in ('Invitation', 'AccessibleJob', 'ExclusiveJob') AND
                invites.responded = false AND
                invites.status = 'active'").
              where("invites.user_id = ?", user.id).distinct
          else
            open_jobs.
              joins("
                LEFT OUTER JOIN affiliates as invites ON
                  invites.job_id = jobs.id AND
                  invites.type in ('Invitation', 'ExclusiveJob') AND
                  invites.responded = false AND
                  invites.status = 'active'").
              where("invites.user_id = ?", user.id).distinct
          end
        }

        scope :recruiters_count_sorting, -> (default_order) {
          left_outer_joins(:affiliates).
            where(affiliates: { status: ['saved'] }).
            group('jobs.id').
            get_order(
              Arel.sql(
                "distinct(affiliates.user_id)"
              ).count, default_order
            )
        }

        scope :disqualified_count_sorting, ->(current_user, default_order) {
          joins('left outer join talents_jobs on talents_jobs.job_id = jobs.id').
            group('jobs.id').
            get_order(
              Arel.sql(
                "case when talents_jobs.rejected = true then 1 ELSE null END"
              ).count, default_order
            )
        }

        scope :stage_count_sorting, ->(current_user, default_order, order_field) {
          joins('left outer join talents_jobs on talents_jobs.job_id = jobs.id').
            group('jobs.id').
            get_order(
              Arel.sql(
                "case when talents_jobs.stage = '#{order_field.titleize}'
                and talents_jobs.rejected = false then 1 ELSE null END"
              ).count, default_order
            )
        }

        scope :interview_stage_count_sorting, -> (current_user, default_order) {
          fixed_stages = PipelineStep::FIXED_STAGES.map { |a| %Q('#{a}') }.join(", ")
          joins('left outer join talents_jobs on talents_jobs.job_id = jobs.id').
            group('jobs.id').
            get_order(
              Arel.sql(
                "case when talents_jobs.stage not in (#{fixed_stages})
                and talents_jobs.rejected = false then 1 ELSE null END"
              ).count, default_order
            )
        }

        scope :enterprise_sorting, -> (order_field, order, current_user) {
          order ||= 'asc'

          if (order_field == 'saved_at' && current_user.role_group != 2) ||
            order_field.nil? || order_field == 'score'
            order_field = 'published_at'
          end
          case order_field

          when 'published_at', 'stage'
            sortit(order_field, order, current_user)
          when 'sourced', 'invited', 'submitted', 'applied', 'hired'
            left_outer_joins(:talents_jobs).
              group(:id).
              order(
                Arel.sql(
                  "case when talents_jobs.stage = '#{order_field.titleize}'
                  and talents_jobs.rejected = false then 1 ELSE null END"
                ).count.send(order.to_sym)
              )

          when 'interview'
            fixed_stages = PipelineStep::FIXED_STAGES.map { |a| %Q('#{a}') }.join(", ")

            left_joins(:talents_jobs).
              group(:id).
              order(
                Arel.sql(
                  "case when talents_jobs.stage not in (#{fixed_stages})
                  and talents_jobs.rejected = false then 1 ELSE null END"
                ).count.send(order.to_sym)
              )
          when 'disqualified'
            left_outer_joins(:talents_jobs).
              group(:id).
              order(
                Arel.sql(
                  "case when talents_jobs.rejected = true then 1 ELSE null END"
                ).count.send(order.to_sym)
              )
          else
            order("jobs.#{order_field} #{order}")
          end
        }

        scope :candidate_opportunities, -> (talent, with_invitation=false) {
          return none unless CsmmScore.table_exists?

          result = open_jobs.joins(csmm_scores: :talent).where(talents: { id: talent.id }).distinct

          if with_invitation
            result.where("
              (
                csmm_scores.user_id = NULL
                and csmm_scores.score >= 0.6
                and jobs.state_obj = talents.state_obj
              ) or (
                jobs.id in (
                  SELECT talents_jobs.job_id FROM talents_jobs
                  LEFT OUTER JOIN rtrs ON rtrs.talents_job_id = talents_jobs.id
                  WHERE talents_jobs.deleted_at IS NULL AND talents_jobs.talent_id = talents.id
                  AND talents_jobs.withdrawn = false
                  AND talents_jobs.stage = 'Invited'
                  AND talents_jobs.rejected = false
                  AND rtrs.rejected_at IS NULL
                )
              )
            ")
          else
            result.where("
              csmm_scores.user_id = NULL
              and csmm_scores.score >= 0.6
              and jobs.state_obj = talents.state_obj
            ")
          end
        }

        scope :ho_dashboard_visibility, -> (user) {
          if user.enterprise_owner? || user.enterprise_admin?
            where(hiring_organization_id: user.hiring_organization_id)
          elsif user.enterprise_manager?
            by_hiring_manager(user)
          elsif user.enterprise_member?
            where(hiring_manager_id: user.id).
              or(
                Job.where(id: HoJobsWatcher.where(user_id: user.id).select(:job_id))
              )
          else
            none
          end
        }

        scope :not_saved_by_talent, -> (talent){
          where.not(id: talent.talents_jobs.reached_at('Submitted').select(:job_id))
        }
      end
    end
  end
end
