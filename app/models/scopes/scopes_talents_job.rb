module Scopes
  module ScopesTalentsJob
    def self.included(receiver)
      receiver.class_eval do
        scope :active, -> { where(active: true) }
        scope :inactive, -> { where(active: false) }
        scope :hiring_in_progress, -> {
          not_withdrawn.where.not(stage: ['Assignment Begins', 'Assignment Ends'])
        }
        scope :for_talent, -> { not_withdrawn.where.not(stage: 'Sourced') }
        [:invited, :signed, :submitted].each do |s|
          scope s, -> { not_withdrawn.where(stage: s.to_s.capitalize) }
        end
        scope :pending, -> { sourced } # not used anywhere
        scope :rejected, -> { where(rejected: true) }
        scope :not_rejected, -> { where(rejected: false) }
        scope :withdrawn, -> { where(withdrawn: true) }
        scope :not_withdrawn, -> { where(withdrawn: false) }
        scope :offered, -> {
          reached_at('Offer')
        }
        scope :applied, -> {
          reached_at('Applied')
        }
        scope :hired, -> {
          reached_at('Hired')
        }
        scope :assignment_begins, -> {
          reached_at('Assignment Begins')
        }
        scope :not_hired, -> {
          where.not(stage: PipelineStep::FILLED_STAGES)
        }
        scope :self_applied, -> {
          not_rejected.not_withdrawn.where(user: nil, interested: true)
        }

        scope :grouped_rejected, -> {
          where("talents_jobs.rejected = true or talents_jobs.withdrawn = true")
        }

        scope :assignment_data, ->(stages, user) {
          where(stage: stages).not_rejected.not_withdrawn.visible_to(user)
        }

        scope :visible_ho_talents, ->(user) {
          visible_to(user).not_rejected.not_withdrawn.where('sort_order >= ?', 1.5)
        }

        scope :visible_to, ->(user) {
          return where(nil) if user.admin? || user.super_admin? || user.customer_support_agent?
          if user.account_manager?
            return where(client_id: user.my_managed_client_ids)
          elsif user.supervisor?
            return where(client_id: user.my_supervisord_client_ids)
          elsif user.onboarding_agent?
            return where(client_id: user.my_onboard_client_ids)
          elsif user.agency_owner_admin?
            return where(agency_id: user.agency_id)
          elsif user.agency_user?
            users = case user.primary_role
                    when 'team admin'
                      user.my_team_users
                    when 'team member'
                      user.my_team_users.team_members
                    end
            return where(user: users)
          elsif user.enterprise_owner? || user.enterprise_admin?
            return by_enterprise_owner_admin(user)
          elsif user.enterprise_manager?
            return by_enterprise_manager(user)
          elsif user.enterprise_member?
            return by_enterprise_member(user)
          end
          return none
        }

        scope :visible_to_user_by_job, ->(user, job_id) {
          job = Job.find(job_id)
          return where(job_id: job_id) if user.admin? || user.super_admin? || user.customer_support_agent? || user.hiring_org_user?

          if user.account_manager?
            # jobs on which account manager is a representer or its submitted by recruiter
            unless job.is_account_manager?(user)
              return where(user_id: user.id, job_id: job_id)
            end
            return where(job_id: job_id)

          elsif user.supervisor?
            # jobs on which supervisor is a representer or account manager
            # is a representer or its submitted by recruiter
            unless job.is_supervisor?(user)
              return where(user_id: user.id, job_id: job_id)
            end
            return where(job_id: job_id) # TODO: TEST CASES NOT WRITTEN

          elsif user.onboarding_agent?
            return none unless job.is_onboarding_agent?(user)
            return where(job_id: job_id) # TODO: TEST CASES NOT WRITTEN

          elsif user.agency_owner_admin?
            return where(agency_id: user.agency_id, job_id: job_id)

          elsif user.agency_user?
            user_ids = (case user.primary_role
                        when 'team admin'
                          user.my_team_users
                        when 'team member'
                          user.my_team_users.team_members
              end).pluck(:id)
            return where(user_id: user_ids, job_id: job_id)
          end

          return none
        }

        # return talents_jobs which is on stage right. ex: sourced, interviewed, rejected, withdrawn ...
        # return a result which belongs to a group of stages if group parameter is true.
        scope :by_stage, -> (stage, group, tag = nil) {
          return where(nil) if stage.blank?
          return send "grouped_#{stage.downcase}" if group
          case stage.downcase
          when 'rejected'
            rejected
          when 'withdrawn'
            withdrawn
          else
            results = not_rejected.not_withdrawn
            results = stage == 'signed' ?
              results.where("(stage = ?) OR (stage is null and interested = ?)", stage, true) :
              results.where(stage: stage)
            if tag
              results = results.joins(:completed_transitions).where(
                completed_transitions: {
                  stage: stage, tag: tag, current: true,
                }
              )
            end
            results
          end
        }

        # returns talents_jobs which has reached to a particular stage
        scope :reached_at, ->(stage) {
          return where(nil) if stage.blank?
          minumum_sort_order = PipelineStep::FIXED_DETAILED_STAGES.
            select{|fixed_stage| fixed_stage[:stage_label] == stage}[0][:stage_order]

          where("sort_order >= ?", minumum_sort_order)
        }

        # returns talents_jobs which has reached to a particular stage
        scope :reached_at_interview, -> {
          return where("sort_order >= 2")
        }

        # returns talents_jobs which has reached to a particular stage
        scope :at_interview, -> {
          return where("sort_order >= 2 and sort_order < 3")
        }

        # returns talents_jobs which has been rejected after a particular stage
        scope :rejected_or_withdrawn_after, ->(stage) {
          return where(nil) if stage.blank?
          return grouped_rejected.where("stage ILIKE ?", stage)
        }

        scope :rejected_or_withdrawn_after_submission, -> {
          return grouped_rejected.where("sort_order >= 1.4")
        }

        scope :not_rejected_or_withdrawn, ->(stage, tag = nil) {
          return where(nil) if stage.blank?
          results = not_rejected.not_withdrawn.where("stage ILIKE ?", stage)
          results = results.where(completed_transitions: { stage: stage, tag: tag, current: true }) if tag
          results
        }

        scope :submittable_talents, ->(user) {
          editable_talents_at_stage(user, ['Signed'])
        }

        # TODO: add test cases
        scope :editable_talents_at_stage, ->(user, stages) {
          list = PipelineStep::FIXED_STAGES
          from_stage = user.my_jobs_permissions['move org candidate from stage']
          to_stage = user.my_jobs_permissions['move org candidate till stage']
          if from_stage && to_stage && ((begin
                                           list[list.index(from_stage)..list.index(to_stage)]
                                         rescue
                                           []
                                         end) & stages).any?
            return visible_to(user).not_rejected.not_withdrawn.where(
              stage: stages
            )
          end
          from_stage = user.my_jobs_permissions['move own candidate from stage']
          to_stage = user.my_jobs_permissions['move own candidate till stage']
          if from_stage && to_stage && ((begin
                                           list[list.index(from_stage)..list.index(to_stage)]
                                         rescue
                                           []
                                         end) & stages).any?
            return where(user_id: user.id).not_rejected.not_withdrawn.where(
              stage: stages
            )
          end
          return none
        }

        scope :rp_notifications, -> (user) {
          includes(:pipeline_notifications).where(pipeline_notifications: { user_id: user.id })
        }

        scope :unread_notifications, -> (user, stage) {
          rp_notifications(user).where(pipeline_notifications: { stage: stage })
        }

        scope :interview_unread_notifications, -> (user) {
          rp_notifications(user).where.
            not(pipeline_notifications: { stage: PipelineStep::FIXED_STAGES })
        }

        scope :disqualified_unread_notifications, -> (user) {
          rp_notifications(user).where(
            "pipeline_notifications.rejected = ? OR pipeline_notifications.withdrawn = ?", true, true
          )
        }

        scope :qualified_unread_notifications, -> (user) {
          rp_notifications(user).where(
            "pipeline_notifications.rejected = ? OR pipeline_notifications.withdrawn = ?", false, false
          )
        }

        scope :submittable, ->(user) {
          editable_talents_at_stage(user, %w(Sourced Invited Signed))
        }

        scope :disqualified_at_stage, -> (stage, user, start_period, end_period, options) {
          where(stage: stage, withdrawn: false, rejected: true).joins(:metrics_stages).where({
            metrics_stages: {
              stage: "Rejected", created_at: (start_period..end_period),
            },
          }.merge(options)).visible_to(user)
        }

        scope :withdrawn_at_stage, -> (stage, user, start_period, end_period, options) {
          where(stage: stage).joins(:metrics_stages).where({
            metrics_stages: {
              stage: "Withdrawn", created_at: (start_period..end_period),
            },
          }.merge(options)).visible_to(user)
        }

        scope :sortit, ->(order_field, order, user = nil) {
          default_order = order.presence || 'desc'
          order_field = order_field.presence || 'updated_at'
          case order_field
          when 'employee_name'
            joins('left outer join talents t1 on t1.id = talents_jobs.talent_id')
              .order('t1.first_name ASC, t1.last_name ASC, t1.created_at DESC')
          when 'first_name'
            joins('left outer join talents t1 on t1.id = talents_jobs.talent_id').
              get_order(Arel.sql("t1.first_name"), default_order)
          when 'title'
            joins(:job).get_order(Arel.sql("jobs.title"), default_order)
          when 'client_name'
            joins(:client).get_order(Arel.sql("clients.company_name"), default_order)
          when 'type_of_job'
            joins(:job).get_order(Arel.sql("jobs.type_of_job"), default_order)
          when 'assignment_end_date'
            joins(:assignment_detail).
              get_order(Arel.sql("assignment_details.end_date"), default_order)
          when 'start_date'
            joins(:assignment_detail).
              get_order(Arel.sql("assignment_details.start_date"), default_order)
          when 'salary'
            joins(:assignment_detail).
              get_order(Arel.sql("assignment_details.salary"), default_order)
          when 'possibility_of_extension'
            joins(:assignment_detail).
              get_order(
                Arel.sql("assignment_details.possibility_of_extension"),
                default_order
              )
          when 'duration_period'
            joins(:assignment_detail).
              get_order(
                Arel.sql(
                  "EXTRACT(EPOCH FROM assignment_details.end_date) -
                  EXTRACT(EPOCH FROM assignment_details.start_date)"),
                  default_order
                )
          when 'comments_sort'
            joins("left outer join
              (#{Note.visible_to(user).unread_without_order(user).to_sql})
                AS ac ON ac.notable_id = talents_jobs.id"
              ).
              group('talents_jobs.id').
              order("COUNT(ac.id) #{default_order}")
          when 'disqualified_sort'
            order('rejected, updated_at DESC')
          else
            order(order_field => default_order)
          end
        }

        scope :for_open_jobs, -> {
          left_outer_joins(:job).
            where(jobs: { stage: Job::STAGES_FOR_APPLICATION })
        }

        scope :acknowledged_disqualified, -> (user) {
          joins(:acknowledge_disqualified_users).
            where(acknowledge_disqualified_users: { user_id: user.id }).
            order(created_at: :desc)
        }

        scope :unacknowledged_disqualified_with_count, -> (job_ids, user) {
          tjs = user.hiring_org_user? ? applied : TalentsJob

          tjs.where(job_id: job_ids)
            .visible_to(user).rejected
            .where.not(
              id: acknowledged_disqualified(user).select(:talents_job_id),
              rejected_by_id: user.id
            )
            .group(:job_id).count
        }

        scope :by_enterprise_owner_admin, -> (user) {
          where(hiring_organization_id: user.hiring_organization_id)
        }

        scope :by_enterprise_manager, -> (user) {
          by_enterprise_member(user)
        }

        scope :by_enterprise_member, -> (user) {
          where(
            job_id: Job.my_jobs(user).select(:id)
          )
        }

        scope :hiring_unlocked_candidates, -> (user) {
          where.not(stage: PipelineStep::GROUPED_STAGES[:Submitted]).
            or(TalentsJob.where(user_id: user.hiring_organization.user_ids))
        }

        scope :active_invited, -> {
          invited.
            not_rejected.
            left_outer_joins(:all_rtr).
            where(rtrs: { rejected_at: nil })
        }
      end
    end
  end
end
