require 'csmm/match_maker'
module ModelCallback
  module CallbacksJob

    def self.included(receiver)
      receiver.class_eval do
        before_validation :init_address
        before_validation :init_fields
        before_validation :init_stage
        before_save :init_date
        before_validation :init_job_id, on: :create
        after_validation :compute_job_score
        after_create :set_job_count_to_client, :set_industry_id
        after_destroy :set_job_count_to_client
        # after_destroy :hide_children
        before_validation :save_job_for_user, on: :create
        after_save :queue_job
        after_update :on_close_withdraw_talents
        after_update :on_close_cancel_events
        after_update :unnhold_job
        after_save :update_hold_field
        after_commit :init_media, on: :create
        before_save :check_for_valid_agencies
        after_save :expire_invitation_url
        after_save :update_stage_for_beeline
        after_save :actions_after_publishing_job
        after_save :queue_smart_distribution_job, unless: :is_reopening?
        after_save :unhold_job_on_close
        after_save :show_to_rectricted_access,
                   :show_to_exclusive_access
        after_save :set_max_applied_limit
        after_save :actions_when_exclusivity_ends
        after_save :reindex_talents_jobs
        after_save :job_autounhold
        after_update :set_closed_job_events_active_false

        after_save :on_close_update_badges

        after_create :create_cs_job_id
        after_update :update_cs_job_id

        after_save :save_changes_in_history
        after_commit :handle_csmm_update
        after_update :invite_recruiters_if_reopen, if: :is_reopening?
      end
    end

    ########################

    private

    ########################

    def is_reopening?
      saved_change_to_stage == ['Closed', 'Open'] or saved_change_to_stage == ['On Hold', 'Open']
    end

    def invite_recruiters_if_reopen
      if Rails.env.development? || Rails.env.test?
        return
      end

      SmartDistributionJob.set(wait_until: 10.seconds.from_now).perform_later(self, true)
    end

    def handle_csmm_update
      if Rails.env.test? || Rails.env.development?
        return
      end

      CsmmTaskHandlerJob.set(wait_until: 10.seconds.from_now).perform_later(
        'handle_job_save',
        { job_id: id, changes: previous_changes.keys, _version: 2 }
      )
    end

    def init_stage
      if will_save_change_to_stage?
        reason, note = get_reason_and_note
        self.stage_transitions[Time.now] = {
          stage: stage.gsub(' ', '-'), reason: reason, note: note,
        }
      end
      return if !['Draft', 'Scheduled', 'Under Review', nil].include?(stage)
      if published_at.blank? && created_by.hiring_org_user?
        self.stage = ho_published_at.present? ? 'Under Review' : 'Draft'
        self.priority_of_status = ho_published_at.present? ? 6 : 5
        self.visible_to_cs = !stage.eql?('Draft')
      elsif published_at.present? && published_at <= Time.now.utc
        self.stage = 'Open'
        self.enable = true
        self.priority_of_status = 3
      elsif published_at.present? && published_at >= Time.now.utc
        self.stage = 'Scheduled'
        self.priority_of_status = 4
      elsif on_hold?
        self.priority_of_status = 2
      end
    end

    def get_reason_and_note
      case stage
      when 'Open'
        if stage_in_database == 'Closed'
          [reason_to_reopen, '']
        elsif stage_in_database == 'On-Hold'
          [reason_to_unhold_job, '']
        end
      when 'Closed'
        [reason_to_close_job, closed_note]
      when 'On-Hold'
        [reason_to_onhold_job, '']
      end
    end

    def init_fields
      self.logo = client['logo']
      self.image_resized = client.image_resized

      if currency
        self.currency_obj = Currency.where(abbr: currency).first.as_json(only: [:id, :abbr, :name])
      end

      self.hiring_organization_id = hiring_organization_id || billing_term&.hiring_organization_id

      self.available_positions = positions - (filled_positions || 0) if positions
      self.pay_period = pay_period || duration_period

      if changed.include?('is_onhold') && is_onhold
        self.on_hold_at = Time.now
        self.opened_at = self.closed_at = nil
      elsif changed.include?('stage') && open?
        self.opened_at = Time.now
        self.on_hold_at = self.closed_at = nil
      elsif changed.include?('stage') && closed?
        self.closed_at = Time.now
        self.opened_at = self.on_hold_at = nil
      end

      if billing_term.blank? && created_by.hiring_org_user?
        self.billing_term_id = get_billing_term&.id
      end
    end

    def check_for_valid_agencies
      return unless is_private
      return unless changed.include?('id')
      self.agency_ids = picked_by.pluck(:agency_id).uniq
    end

    def init_media
      return if client.blank?
      return if clone_job.is_true?
      job_media = []
      client.media.each do |cm|
        jm = cm.dup
        jm.file = cm['file']
        job_media << jm
      end
      media << job_media
    end

    def update_hold_field
      return if is_onhold?
      auto_hold if changed.include?('max_applied_limit')
    end

    def update_unhold_field
      return unless is_onhold?
      unhold if changed.include?('max_applied_limit')
    end

    # initialize date in Date or Date time format
    def init_date
      start_date = nil if start_date.blank?
      published_at = nil if published_at.blank?
      return if start_date.nil? && published_at.nil?
      self.start_date = Date.parse(start_date) if start_date.is_a?(String)
      (self.published_at = published_at.is_a?(String) ? DateTime.parse(published_at).utc : published_at.utc) if published_at
    end

    # if client is direct and uses no vms, system will generate job_id and that is is not editable
    def init_job_id
      return if job_id.present? || client.nil? || type_of_job.blank?
      self.job_id = [
        client.company_name[0..3],
        type_of_job[0..1],
        category ? category.name[0..1] : '',
        Time.now.to_i.to_s,
      ].join.upcase
    end

    # catch total job count a client is posted
    def set_job_count_to_client
      client.update_column(:jobs_count, client.jobs.count)
    end

    # Any job created by a user will automatically be saved in their My Jobs.
    # Any job of a client, will automatically be saved by its account managers in their My Jobs.
    def save_job_for_user
      self.supervisor_id = supervisor_id.presence || client.primary_supervisor&.id
      self.account_manager_id = account_manager_id.presence || client.primary_account_manager&.id
      self.onboarding_agent_id = onboarding_agent_id.presence || client.primary_onboarding_agent&.id
    end

    # queue a job when it has to publish.
    def queue_job
      # Sidekiq PublishJob
      return if published_at.nil? || published? || changed.exclude?('published_at')
      PublishJob.set(wait_until: published_at).perform_later(self)
    end

    def on_close_withdraw_talents
      return unless changed.include?('stage')
      if is_closed?
        # update_column(:closed_at, Time.now)
        return if talents_jobs.not_hired.empty?
        talents_jobs.not_hired.where(withdrawn: false).update_all(active: false)
      else
        # update_column(:closed_at, nil)
        talents_jobs.where(withdrawn: false).update_all(active: true)
        # re initiate all candidate at original stage
      end
    end

    def on_close_cancel_events
      return unless changed.include?('stage')
      if is_closed?
        job_events = events.not_declined.where.not('end_date_time <= ?', Time.now)
        if job_events.present?
          job_events.each do |event|
            event.event_cancel_on_job_close(self, 'Job')
          end
        end
        talents_jobs.each do |talents_job|
          talents_job_events = talents_job.events.not_declined.where.not('end_date_time <= ?', Time.now)
          talents_job_events.each do |event|
            event.event_cancel_on_job_close(self, 'TalentsJob')
          end
        end
      end
    end

    def unnhold_job
      return unless changed.include?('locked_at')
      return unless enable && is_onhold

      update_columns(
        is_onhold: false,
        reason_to_unhold_job: 'Job enabled',
        stage_transitions: stage_transitions.merge(
          Time.now => { stage: 'Open', reason: 'Job enabled' }
        )
      )
      SystemNotifications.set(wait: 10.seconds).perform_later(self, 'job_unhold', nil, nil)
    end

    def set_industry_id
      update_attributes(industry_id: client.industry_id)
    end

    def expire_invitation_url
      return unless changed.include?('stage')
      if is_closed?
        talents_jobs.update_all(invitation_token: nil)
        EventAttendee.attendees_events(event_ids).update_all(invitation_token: nil)
        affiliates.active.update_all(status: 'dismissed', dismissed_reason: 'Job closed', responded: true)
      elsif is_onhold?
        affiliates.active.update_all(status: 'dismissed', dismissed_reason: 'Job went on-hold', responded: true)
      elsif open?
        AccessibleJob.where(status: 'dismissed', dismissed_reason: ['Job closed', 'Job went on-hold']).
          update_all(status: 'active', dismissed_reason: nil, responded: false)
        if exclusive_access_end_time && exclusive_access_end_time > Time.now
          ExclusiveJob.where(status: 'dismissed', dismissed_reason: ['Job closed', 'Job went on-hold']).
            update_all(status: 'active', dismissed_reason: nil, responded: false)
        end
      end
      ReindexObjectJob.perform_later(self)
    end

    # queue a job for smart distribution when it published.
    def queue_smart_distribution_job
      not_to_queue = published_at.blank? ||
        Rails.env.test? || Rails.env.development? ||
        is_private? || !visible_to_cs? || is_closed? ||
        (changes.keys & (Job::JOB_SCORE_VALUES.keys.map(&:to_s) + ['published_at', 'exclusive_access_end_time'])).blank?
      return if not_to_queue

      if distributions.where(type_of_distribution: :system).count == 0
        Rails.logger.info "queuing smart distribution"
        if exclusive_access_end_time.nil? || exclusive_access_end_time < Time.now.utc
          # 3 minutes wait has been given so that by that time entities are recognized
          SmartDistributionJob.set(wait_until: [published_at + 3.minutes, 3.minutes.from_now].max)
            .perform_later(self)
        else
          SmartDistributionJob.set(wait_until: exclusive_access_end_time + 35.minutes)
            .perform_later(self)
        end
      end
    end

    def unhold_job_on_close
      return unless is_closed? && is_onhold
      update_columns(is_onhold: false, reason_to_unhold_job: 'Job closed', on_hold_at: nil)
    end

    def actions_after_publishing_job
      return if published_at.nil? || !changed.include?('stage')

      if ['Scheduled', 'Draft', 'Under Review'].include?(stage_was) && open?
        if published?
          SystemNotifications.
            set(wait: 10.seconds).
            perform_later(self, 'job_published', published_by, nil)

          if created_by.hiring_org_user?
            JobsMailer.
              job_published_notify(created_by, self, { sender: published_by }).
              deliver_now
          end

          add_exclusive_access_end_time
        end
      end
    end

    def show_to_rectricted_access
      if (changed.include?('stage') && ['Scheduled', 'Draft', 'Under Review'].include?(stage_was)) ||
        (changed & %w(hiring_organization_id billing_term_id client_id)).any?

        ShowToRestrictedAccessJob.set(wait: 10.seconds).perform_later('jobs', id)
      end
    end

    def show_to_exclusive_access
      if (changed.include?('stage') && ['Scheduled', 'Draft', 'Under Review'].include?(stage_was)) ||
        changed.include?('billing_term_id')

        ShowToExclusiveAccessJob.set(wait: 10.seconds).perform_later('jobs', id)
      end
    end

    def actions_when_exclusivity_ends
      return unless changed.include?('exclusive_access_end_time')
      if exclusive_access_end_time.nil? || exclusive_access_end_time < Time.now.utc
        AutoDismissalExclusiveJob.set(wait: 10.seconds).perform_later(id)
      end
    end

    def job_autounhold
      return unless changed.include?('max_applied_limit')
      unhold
    end

    def set_max_applied_limit
      return if changed.include?('max_applied_limit')
      return unless changed.include?('positions')
      update_column(:max_applied_limit, (positions * 10))
      if total_active_applied_count >= max_applied_limit
        auto_hold
      else
        unhold
      end
    end

    def reindex_talents_jobs
      indexed_fields = %w(
        country_obj
        state_obj
        stage
        category_id
        suggested_pay_rate
        suggested_bill_rate
        visible_to_cs
        account_manager_id
        client_id
        hiring_manager_id
        hiring_watcher_ids
        hiring_organization_id
        exclusive_access_end_time
        billing_term_id
        is_private
        industry_id
        type_of_job
      )
      return unless (saved_changes.keys & indexed_fields).any?
      ReindexObjectJob.set(wait: 10.seconds).perform_later(talents_jobs.to_a)
      ReindexObjectJob.set(wait: 10.seconds).perform_later(affiliates.to_a)
      ReindexObjectJob.set(wait: 10.seconds).perform_later(metrics_stages.to_a)
    end

    def set_closed_job_events_active_false
      return unless changed.include?('stage')
      return unless is_closed?
      Event.joins(:job).where(job_id: id).update_all(active: false)
    end

    def on_close_update_badges
      return unless changed.include?('stage')
      return unless is_closed?
      Badge.where(job_id: id).destroy_all
      stats = leaderboard_statistics
      stats.each do |badge, values|
        if values == {} || values.blank? || values[:recruiters].blank?
          next
        end
        badge_name = badge.to_s.split('_').collect { |x| x.capitalize }.join(' ')
        values[:recruiters].each do |recruiter|
          Badge.create(job_id: id, user_id: recruiter[:id], badge_label: badge_name)
        end
      end
    end

    def create_cs_job_id
      new_cs_job_id = create_new_cs_job_id(self)
      update_columns(
        cs_job_id: new_cs_job_id,
        display_job_id: get_display_job_id(job_id, new_cs_job_id)
      )
    end

    def update_cs_job_id
      return unless changed.include?('job_id')
      cs_id = cs_job_id ||= create_new_cs_job_id(self)
      update_column(:display_job_id, get_display_job_id(job_id, cs_id))
    end

    def get_display_job_id(j_id, cs_id)
      [j_id, cs_id].join('|')
    end

    def create_new_cs_job_id(job)
      new_cs_job_id = "#{job.client.initials}-#{job.hiring_organization.initials}-#{rand(1..99999)}"
      while Job.where(cs_job_id: new_cs_job_id).any?
        new_cs_job_id = "#{job.client.initials}-#{job.hiring_organization.initials}-#{rand(1..99999)}"
      end
      new_cs_job_id
    end

    def save_changes_in_history
      if changed.include?('suggested_pay_rate')
        change_histories.where(column_name: 'pay rate').order(created_at: :desc).
          first&.update_columns(last_updated_at: DateTime.now)
        change_histories.create(
          column_name: 'pay rate',
          current_value: (suggested_pay_rate['min'].to_f + suggested_pay_rate['max'].to_f) / 2.to_f,
          user_id: updated_by&.id
        )
      end

      if changed.include?('marketplace_reward')
        change_histories.where(column_name: 'reward').order(created_at: :desc).
          first&.update_columns(last_updated_at: DateTime.now)
        change_histories.create(
          column_name: 'reward',
          current_value: (marketplace_reward['min'].to_f + marketplace_reward['max'].to_f) / 2.to_f,
          user_id: updated_by&.id
        )
      end

      if changed.include?('incumbent_bill_rate')
        change_histories.where(column_name: 'bill rate').order(created_at: :desc).
          first&.update_columns(last_updated_at: DateTime.now)
        change_histories.create(
          column_name: 'bill rate',
          current_value: (incumbent_bill_rate['min'].to_f + incumbent_bill_rate['max'].to_f) / 2.to_f,
          user_id: updated_by&.id
        )
      end
    end

    def compute_job_score
      self.job_score = compute_job_completeness
    end
  end
end
