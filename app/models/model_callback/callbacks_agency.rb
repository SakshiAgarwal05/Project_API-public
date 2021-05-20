module ModelCallback
  module CallbacksAgency
    include Concerns::AcronymGenerator

    def self.included(receiver)
      receiver.class_eval do
        before_validation :init_address
        before_destroy :if_destroyable
        after_save :show_to_rectricted_access
        after_save :expire_cache
        after_commit :update_restrict_access, :update_invitations
        after_create :generate_initials
      end
    end

    ########################
    private
    ########################

    def expire_cache
      return if (changed & ['id', 'login_url']).blank?
      Rails.cache.delete('agency_subdomains')
    end

    def update_restrict_access
      users.update_all(restrict_access: !!restrict_access)
      users.each { |user| ReindexObjectJob.set(wait: 10.seconds).perform_later(user) }
    end

    def update_invitations
      return unless changed.include?('restrict_access')
      agency.invitations.delete_all
      ReindexManuallyInvitedRecruitersJob.set(wait: 1.minutes).perform_later(id)
    end

    def if_destroyable
      return true unless if_valid
      engaged_recruiters = users.eager_load(talents_jobs: :metrics_stages).
        where(
          metrics_stages: { stage: 'Signed' },
          talents_jobs: { withdrawn: false }
        ).pluck(:first_name)

      if engaged_recruiters.any?
        self.errors.add(
          :base,
          "Some candidates have signed RTR with #{engaged_recruiters.join(', ')}. Please transfer their RTR to other user first."
        )
        return false
      end
      return true unless self.enabled
      self.errors.add(:base, "Can't delete a enabled agency.")
      return false
    end

    def generate_initials
      create_initials(Agency, id, company_name)
    end
  end
end
