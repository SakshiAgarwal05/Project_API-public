module ModelCallback
  # CallbacksProfile
  module CallbacksProfile
    def self.included(receiver)
      receiver.class_eval do
        # after_save :send_email_to_talent
        before_destroy :check_active_job
        before_validation :init_agency
        before_save :init_address
      end
    end

    ########################
    private
    ########################

    def init_agency
      self.agency_id = profilable.agency_id if profilable.is_a?(User)
    end

    def check_active_job
      return if talents_jobs.active.empty?
      errors.add(:base, I18n.t('profile.error_messages.cant_delete_profile'))
    end

    # def send_email_to_talent
    #   return unless talents_job
    #   return if changed.include?('id') || changed.blank?
    #   TalentMailer.notify_talent_about_profile_change(self, changed).deliver
    # end
  end
end
