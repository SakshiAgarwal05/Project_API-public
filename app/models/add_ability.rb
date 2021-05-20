# frozen_string_literal: true

# This module is used for sending abilities according to the user.
module AddAbility
  # can?(...) feature is available only in controllers.
  # To make it available in models we need
  # to apply following code for each model.
  # You Don't need to call it. can? methods
  # will be available on just including the module.
  def ability
    @ability ||= Ability.new(self)
  end

  delegate :can?, :cannot?, to: :ability

  # ==== How to use it?
  # * Include the module in the class for which you want the list of permissions
  #     class Job
  #       include AddAbility
  #       ...
  #     end
  # * create a class accessor
  #     class Job
  #       include AddAbility
  #       cattr_accessor :current_user
  #       ...
  #     end
  # * there are two ways to get list of powers
  #     Job.first.powers(User.first)
  #   or
  #     LoggedinUser.current_user = User.first
  #     Job.first.powers
  # ==== Why current user is set in class?
  # let's concider a example of Job. If logged in user is a team member,
  # and he is on Job list page, we may need information what that user can do with each job.
  # There may be some jobs which he can edit and there may be some jobs which he can only read.
  # In JSON methods we can not pass arguments and so can't send powers with each job.
  # We need to write a different action just to show permissions for that
  # job allowed to user which means if there are
  # 50 jobs there will be 50 api requests. But if we set class accessor
  # in the action we just
  # need to include <tt>powers</tt> in methods and it will list all the
  # permissions allowed to that user for each job.
  #     def index
  #       LoggedinUser.current_user = User.first
  #       Job.page(page_count).per(per_page).as_json(methods: [:powers])
  #     end
  # ==== Example
  #     {
  #       read: true,
  #       create: true,
  #       update: true,
  #       destroy: false
  #       account_managers: {
  #         read: true,
  #         create: true
  #       }
  #     }

  def powers(user = nil, action_lists=['all'])
    user ||= LoggedinUser.current_user
    return {} unless user.is_a?(User)

    case self
    when Client
      abilities_for_client(user, action_lists)
    when Agency
      abilities_for_agency(user, action_lists)
    when Team
      abilities_for_team(user, action_lists)
    when Job
      abilities_for_job(user, action_lists)
    when TalentsJob
      abilities_for_talents_job(user, action_lists)
    when Talent
      abilities_for_talent(user, action_lists)
    when User
      abilities_for_user(user, action_lists)
    when HiringOrganization
      abilities_for_hiring_organization(user, action_lists)
    when BillingTerm
      abilities_for_billing_term(user, action_lists)
    when Group
      abilities_for_group(user, action_lists)
    when Event
      abilities_for_event(user, action_lists)
    else
      common_abilities(user, action_lists)
    end
  end

  private

  def common_abilities(user, action_lists)
    {
      create: user.can?(:create, self.class),
      read: user.can?(:read, self),
      update: user.can?(:update, self),
      destroy: user.can?(:destroy, self)
    }
  end

  def abilities_for_billing_term(user, action_lists)
    {
      create: user.can?(:create, self.class),
      read: user.can?(:read, self),
      update: user.can?(:update, self),
      destroy: user.can?(:destroy, self),
      enable: user.can?(:enable, self)
    }
  end

  def abilities_for_client(user, action_lists)
    read_permission = user.can?(:read, self)
    update_permission = user.can?(:update, self)

    {
      create: user.can?(:create, self.class),
      read: read_permission,
      update: update_permission,
      destroy: user.can?(:destroy, self),
      create_my: false,
      account_managers: user.can?(:account_managers, self),
      enable: user.can?(:enable, self),
      agency_members: user.can?(:agency_members, self),
      jobs: user.can?(:jobs, self),
      assign_supervisor: user.can?(:assign_supervisor, self),
      assign_account_manager: user.can?(:assign_account_manager, self),
      assign_onboarding_agent: user.can?(:assign_onboarding_agent, self),
      assigned_cs_team: user.can?(:assigned_cs_team, self),
      recruiters: user.can?(:recruiters, self),
      toggle_save: user.can?(:toggle_save, self),
      remove_recruiters: user.can?(:remove_recruiters, self),
      read_recruitment_pipeline: read_permission,
      read_contact: read_permission,
      update_contact: update_permission,
      destroy_contact: update_permission,
      create_contact: update_permission,
      client_my_tabs: client_my_tabs(user),
      client_message_options: client_message_options(user),
      can_assign: (user&.agency&.users&.count&.> 1),
      assign_recruiters: (user.can?(:assign_recruiters, self) && (user.agency.nil? || user.agency.users.count > 1)),
      my_client: if_my_client(user),
      invite_recruiter: ['onboarding agent'].exclude?(user.primary_role),
      bulk_email_recruiter: ['onboarding agent', 'team member'].exclude?(user.primary_role),
      create_event: user.can?(:create, Event),
      view_onboarding_agent: user.internal_user?,
      can_add_job: billing_terms.enabled.any?,
      view_supervisor: user.internal_user?
    }
  end

  def abilities_for_job(user, action_lists)
    create_talents_jobs_condition = user.can?(:create, TalentsJob) && not_closed && if_saved(user)
    jrp_permission = user.can?(:job_recruitment_pipeline, self)
    jop_permission = user.can?(:job_onboarding_package, self)
    user_agency = user.agency
    up_count = user_agency ? user_agency.users.count : 0
    my_job = if_my_job(user)
    read_permission = user.can?(:read, self)

    {
      create: user.can?(:create, self.class),
      read: read_permission,
      update: user.can?(:update, self) && !user.onboarding_agent?,
      destroy: user.can?(:destroy, self),
      create_my: false,
      show: user.can?(:show, self),
      publish: user.can?(:publish, self),
      active_candidates: user.can?(:active_candidates, self),
      save: user.can?(:save, self),
      unsave: user.can?(:unsave, self),
      remove_recruiter: user.can?(:remove_recruiter, self),
      close: user.can?(:close, self),
      toggle_hold: user.can?(:toggle_hold, self),
      assign_account_manager: user.can?(:assign_account_manager, self),
      assign_onboarding_agent: user.can?(:assign_onboarding_agent, self),
      assign_supervisor: user.can?(:assign_supervisor, self),
      detailed_statistics: user.can?(:detailed_statistics, self),
      set_open: user.can?(:set_open, self),
      set_draft: user.can?(:set_draft, self),
      reopen: user.can?(:reopen, self),
      find_matching_candidates: user.can?(:find_matching_candidates, self),
      invite_recruiter: user.can?(:invite_recruiter, self) &&
        user.internal_user? &&
        !user.id.eql?(id),
      create_talents_jobs: create_talents_jobs_condition,
      can_invite: create_talents_jobs_condition,
      job_my_tabs: job_my_tabs(user),
      job_index_tabs: user.can?(:earning, self),
      read_recruitment_pipeline: read_permission,
      change_recruitment_pipeline: jrp_permission && talents_jobs.count.zero?,
      create_recruitment_pipeline: jrp_permission,
      update_recruitment_pipeline: jrp_permission,
      destroy_recruitment_pipeline: jrp_permission,
      job_message_options: job_message_options(user),
      can_assign: up_count > 1,
      assign_recruiter: (user.can?(:assign_recruiter, self) && (user_agency.nil? || up_count > 1)) || (user.agency_user? && user.my_agency_users.count > 1),
      my_job: my_job,
      reschedule: user.can?(:publish, self),
      enable: user.can?(:enable, self),
      can_unassign_recruiter: user.can?(:can_unassign_recruiter, self),
      can_update_onboarding: user.can?(:update, self),
      can_submit: talents_jobs.submittable_talents(user).any?,
      create_event: open_job,
      create_note: open_job,
      valid_job: open_job,
      view_onboarding_agent: user.internal_user?,
      view_supervisor: user.internal_user?,
      toggle_portal_visibility: can_be_restricted? && user.can?(:update, self) && my_job,
      toggle_privacy: can_be_restricted? && user.can?(:update, self) && my_job,
      create_announcement: Job::STAGES_FOR_APPLICATION.include?(stage) && (user.internal_user? || user.hiring_org_user?),
      shareable_options: my_job && ['Draft', 'Scheduled'].exclude?(stage) && enable_shareable_link.is_true?,
      publishing_options: user.can?(:update, self) &&
        (user.internal_user? || user.hiring_org_user?) &&
        my_job &&
        ['Draft', 'Scheduled', 'Closed'].exclude?(stage),
      assign_hiring_users: (user.internal_user? && user.can?(:update, self) && my_job) ||
        (user.hiring_org_user? && hiring_organization_id.eql?(user.hiring_organization_id)),
      job_scorecard: user.can?(:job_scorecard, self),
      job_completeness_score: user.can?(:job_completeness_score, self),
      view_applicants: user.can?(:index, Shareable),
    }
  end

  def abilities_for_agency(user, action_lists)
    create_permission = user.can?(:create, Agency)

    {
      create: create_permission,
      read: user.can?(:read, self),
      update: user.can?(:update, self),
      destroy: user.can?(:destroy, self),
      teams: {
        read: user.can?(:read, Team),
        create: user.can?(:create, Team)
      },
      notes: {
        read: user.can?(:read, Note),
        create: user.can?(:create, Note)
      },
      team_members: {
        read: user.can?(:read, User),
        create: user.can?(:create, User.new(agency: self))
      },
      enable: user.can?(:enable, self),
      agency_index_tabs: agency_index_tabs(user),
      show_actions_tab: user.internal_user?
    }
  end

  def abilities_for_hiring_organization(user, action_lists)
    read_permission = user.can?(:read, self)
    update_permission = user.can?(:update, self)
    crp_permission = user.can?(:staffing_recruitment_pipeline, self)

    {
      create: user.can?(:create, self.class),
      read: read_permission,
      update: update_permission,
      destroy: user.can?(:destroy, self),
      enable: user.can?(:enable, self),
      read_contact: read_permission,
      update_contact: update_permission,
      destroy_contact: update_permission,
      create_contact: update_permission,
      enable_contact: update_permission,
      create_recruitment_pipeline: crp_permission,
      update_recruitment_pipeline: crp_permission,
      destroy_recruitment_pipeline: crp_permission,
      read_recruitment_pipeline: read_permission,
      invite_users: user.can?(:invite_users, self),
    }
  end

  def abilities_for_talent(user, action_lists)
    {
      create: user.can?(:create, self.class) && user.internal_user?,
      read: user.can?(:read, self),
      update: user.can?(:update, self),
      destroy: user.can?(:destroy, self),
      create_my: user.can?(:create, self.class) && user.agency_user?,
      release: user.can?(:release, self),
      enable: user.can?(:enable, self),
      transfer_rtr: user.can?(:transfer_rtr, self),
      preferences: user.can?(:preferences, self),
      unsave: user.can?(:unsave, self),
      save: user.can?(:save, self),
      send_password_instructions: user.can?(:send_password_instructions, self),
      save_candidate: user.can?(:create, TalentsJob) && if_available,
      talent_my_tabs: talent_my_tabs(user),
      candidate_message_options: user.all_permissions['candidate message user roles'],
      my_candidate: !Talent.my_talents(user).find(id).nil?,
      show_actions_tab_index: !user.agency_id,
      show_actions_tab_my: true,
      show_admin_tab_index: !user.agency_id,
      show_admin_tab_my: true,
      can_submit: user.can?(:submittable_jobs, self) && !do_not_contact,
      can_invite: can_invite?(user),
      can_call: if_available,
      can_email: if_available,
      create_event: user.can?(:create, Event),
      create_reminder: user.can?(:create, Reminder),
    }
  end

  def abilities_for_talents_job(user, action_lists)
    update_permission = user.can?(:update, self)
    al = action_lists

    list = {
      create: required?(al, :create) { user.can?(:create, self.class) },
      read: required?(al, :read) { user.can?(:read, self) },
      update: required?(al, :update) { update_permission },
      destroy: required?(al, :destroy) { user.can?(:destroy, self) },
      create_bill_rate_negotiation: required?(al, :create_bill_rate_negotiation) do
        user.can?(:create_bill_rate_negotiation, rtr)
      end,
      send_letter_of_offer: required?(al, :send_letter_of_offer) do
        user.can?(:send_letter_of_offer, self)
      end,
      reject: required?(al, :reject) { user.can?(:disqualify, self) },
      withdrawn: required?(al, :withdrawn) { user.can?(:withdrawn, self) },
      reinstate: required?(al, :reinstate) { user.can?(:reinstate, self) },
      assign_user: required?(al, :assign_user) { user.can?(:assign_user, self) },
      update_questions: required?(al, :update_questions) { user.can?(:update_questions, self) },
      view_onboard_details: required?(al, :view_onboard_details) do
        user.can?(:view_onboard_details, self)
      end,
      skip_stage: required?(al, :skip_stage) do
        skippable_user?(user) && skippable? && update_permission
      end,
      create_event: required?(al, :create_event) { valid_talents_job? },
      create_notes: required?(al, :create_notes) { valid_talents_job? },
      transfer_rtr: required?(al, :transfer_rtr) do
        user.can?(:transfer_rtr, talent) && !TalentsJob.visible_to(user).find(id).nil?
      end,
      candidate_overview_edit: required?(al, :candidate_overview_edit) do
        job_permission = Job::STAGES_FOR_APPLICATION.include?(job.stage)
        user.hiring_org_user? ? job_permission && !locked_access?(user) : job_permission
      end,
      create_resume: required?(al, :create_resume) do
        job_permission = Job::STAGES_FOR_APPLICATION.include?(job.stage)
        if user.hiring_org_user?
          job_permission &&
          (interested? || self.user.hiring_organization_id.eql?(user.hiring_organization_id))
        else
          job_permission
        end
      end,
      view_all_resume: required?(al, :view_all_resume) do
        if user.hiring_org_user?
          (interested? || self.user.hiring_organization_id.eql?(user.hiring_organization_id))
        else
          true
        end
      end,
      submit_offline: required?(al, :submit_offline) do
        user.can?(:submit_offline, self) && valid_sign_offline_obj?
      end,
      enable_actions: required?(al, :enable_actions) { active },
      update_assignment_detail: required?(al, :update_assignment_detail) do
        user.can?(:new, self) || user.can?(:on_assignment, self) || user.can?(:completed, self)
      end,
      create_reminder: required?(al, :create_reminder) { user.can?(:create, Reminder) },
    }.compact

    if (al & [:can_update_event, :can_decline_event]).any?
      lto = latest_transition_obj
      ltoe = lto ? latest_transition_obj.event : nil
      list.merge!(
        can_update_event: required?(al, :can_update_event) { ltoe && user.can?(:update, ltoe) },
        can_decline_event: required?(al, :can_decline_event) { ltoe && user.can?(:destroy, ltoe) },

      )
    end

    if (al & [:update_rtr, :send_revised_rtr]).any?
      update_rtr_permission = user.can?(:update_rtr, self)
      list.merge!(
        update_rtr: required?(al, :update_rtr) { update_rtr_permission },
        send_revised_rtr: required?(al, :send_revised_rtr) { update_rtr_permission },
      )
    end

    list
  end

  def required?(action_list, action)
    if (['all', action].flatten&action_list).any?
      yield
    else
      nil
    end
  end

  def abilities_for_team(user, action_lists)
    {
      create: user.can?(:create, self.class),
      read: user.can?(:read, self),
      update: user.can?(:update, self),
      destroy: user.can?(:destroy, self),
      enable: user.can?(:enable, self),
      team_index_tabs: team_index_tabs(user),
      team_members: { read: user.can?(:read, User), create: user.can?(:create, User) },
      add_members_in_team: user.can?(:create_member, self) && user.agency_user?,
      remove_member_from_team: user.can?(:destroy_member, self) && user.agency_user?
    }
  end

  def abilities_for_user(user, action_lists)
    internal_user_abilities = {
      create: user.can?(:create_internal_users, self.class),
      read: user.can?(:read_internal_users, self),
      update: user.can?(:update_internal_users, self),
      destroy: user.can?(:destroy_internal_users, self),
      enable_internal_users: user.can?(:enable_internal_users, self) && user != self,
      send_password_instructions: user.can?(:send_password_instructions_internal_users, self),
      edit_cs_fields: user.can?(:update_internal_users, self),
      reassign_jobs: user.can?(:reassign_jobs, self)
    }

    external_user_abilities = {
      create: user.can?(:create, self.class),
      read: user.can?(:read, self),
      update: user.can?(:update, self),
      destroy: user.can?(:destroy, self),
      enable: user.can?(:enable, self) && user != self && ['agency owner'].exclude?(primary_role),
      edit_cs_fields: false,
      send_password_instructions: user.can?(:send_password_instructions, self),
      assign_teams: user.can?(:assign_teams, self),
      reassign_team: user.can?(:reassign_team, self) && teams.any? && agency.teams.count > teams.count,
      remove_team: user.can?(:remove_team, self) && teams.any?,
      transfer_rtr: user.can?(:transfer_rtr, self),
      impersonate: user.can?(:impersonate, self),
      invite: user != self,
      reinvite: user.internal_user?,
      revoke_invitation: user.internal_user?,
      password: user.can?(:password, self)
    }

    shared_abilities = {
      assign_clients: user.can?(:assign_clients, self),
      toggle_promote_demote: user.can?(:toggle_promote_demote, self),
      assign_jobs: user.can?(:assign_jobs, self)
    }

    if user.can?(:manage_ho_users, self)
      hiring_org_user_abilities = {
        read: true,
        update: true,
        destroy: true,
        enable: true,
        send_password_instructions: true,
        impersonate: true,
      }
    else
      hiring_org_user_abilities = {
        create: user.can?(:create_enterprise_user, self.class),
        read: user.can?(:read_enterprise_user, self),
        update: user.can?(:update_enterprise_user, self),
        destroy: user.can?(:destroy_enterprise_user, self),
        enable: user.can?(:toggle_enable_enterprise_user, self),
        send_password_instructions: user.can?(:send_password_instructions, self),
      }
    end

    internal_user_abilities.merge!(shared_abilities)
    external_user_abilities.merge!(shared_abilities)

    if internal_user?
      internal_user_abilities
    elsif hiring_org_user?
      hiring_org_user_abilities
    else
      external_user_abilities
    end
  end

  def abilities_for_group(user, action_lists)
    {
      create: user.can?(:create, self.class),
      read: user.can?(:read, self),
      update: user.can?(:update, self),
      destroy: user.can?(:destroy, self),
      enable: user.can?(:enable, self),
    }
  end

  def abilities_for_event(user, action_lists)
    {
      create: user.can?(:create, self.class),
      read: user.can?(:read, self),
      update: user.can?(:update, self),
      destroy: user.can?(:destroy, self),
      mark_as_optional: user.can?(:update, self) && user.eql?(user),
      set_host: user.can?(:update, self) && user.eql?(user),
      remove_attendee: user.can?(:update, self) && Event.my_events(user).find(id) && event_attendees.organizer.where(user_id: user.id).exists?,
      attendee_response: user.can?(:attendee_response, self),
      remove: user.can?(:remove, self),
      decline: user.can?(:decline, self),
      delete: user.can?(:delete, self),
    }
  end
end
