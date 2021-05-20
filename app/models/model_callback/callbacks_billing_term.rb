module ModelCallback
  module CallbacksBillingTerm
    def self.included(receiver)
      receiver.class_eval do
        before_validation :init_fields
        before_destroy :can_destroy
        after_save :update_job_vms, :close_active_jobs
        after_save :show_to_exclusive_access
      end
    end

    private

    def init_fields
      self.client_id = hiring_organization.client_id if direct_staffing?
      self.currency_obj = Currency.find_by(abbr: currency).as_json(only: [:id, :abbr, :name])
    end

    # update vms of existing jobs if client wants to do so.
    # update only those jobs which are pending or open or hold or disabled.
    # notify all related users.
    def update_job_vms
      if !update_vms_for_job || !msp_vms_fee_rate_changed?
        return
      end

      jobs = jobs.where(stage: Job::NOT_CLOSED_STAGES)
      jobs.update_all(msp_vms_fee_rate: msp_vms_fee_rate)
    end

    def close_active_jobs
      if !enable_changed? || !disabled?
        return
      end

      active_jobs.each do |job|
        job.update(
          stage: 'Closed',
          reason_to_close_job: 'Other',
          closed_note: "BillingTerm: #{billing_name} is disabled",
          stage_transitions: job.stage_transitions.merge(
            Time.now => {
              stage: 'Closed',
              reason: "Other",
              note: "BillingTerm: #{billing_name} is disabled",
            }
          ),
        )
      end
    end

    def can_destroy
      return if disabled?
      errors.add(:status, 'should be disabled')
      throw :abort
    end

    def show_to_exclusive_access
      ReindexObjectJob.perform_now(self)
      if agency_ids.nil? || agency_value_old_ids.nil?
        return
      end

      agencies_added_ids = agency_ids - agency_value_old_ids
      agencies_removed_ids = agency_value_old_ids - agency_ids
      if agencies_added_ids.blank? && agencies_removed_ids.blank?
        return
      end

      ShowToExclusiveAccessJob.set(wait: 10.seconds).perform_later('billing_terms', id)
      billing_term_jobs = jobs.active_jobs
      if agencies_added_ids.blank? || billing_term_jobs.count.zero?
        return
      end

      exclusive_jobs = billing_term_jobs.where('exclusive_access_end_time > ?', Time.now.utc)
      users = User.verified.where(agency_id: agencies_added_ids)

      if exclusive_jobs.present? && users.present?
        exclusive_jobs.each do |job|
          users.each do |user|
            JobsMailer.job_exclusive_access_notify(user, job).deliver_later
          end
        end
      end
    end
  end
end
