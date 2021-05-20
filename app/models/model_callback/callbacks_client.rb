module ModelCallback
  module CallbacksClient
    include Concerns::AcronymGenerator

    def self.included(receiver)
      receiver.class_eval do
        before_destroy :check_jobs, prepend: true
        before_validation :init_address
        before_validation :init_timezone
        after_create :set_status_as_new
        before_save :init_industry_name
        after_save :init_job_logo
        after_create :generate_initials
      end
    end


    ########################
    private
    ########################

    def init_job_logo
      return unless (changed & ['image_resized', 'logo']).any?
      jobs.update_all(logo: self['logo'], image_resized: image_resized)
    end

    def init_industry_name
      self.industry_name = industry.name if industry_id_changed?
    end

    def set_status_as_new
      update_column(:status, 'New')
      time = created_at + 1.months
      ChangeClientStatus.set(wait_until: time).perform_later(id)
    end

    def init_timezone
      return if timezone
      self.timezone = contacts.first.try(:timezone) || Timezone.find_by(name: "Pacific Standard Time")
    end

    # check if job exist for the client or not and then let it destroy
    def check_jobs
      return true if destroyable
      if jobs.active_jobs.count > 0
        errors.add(:base, "You cannot disable this client as this client has
          #{jobs.active_jobs.count} active jobs")
        throw :abort
      elsif active
        errors.add(:base, "You cannot delete #{company_name} because it is enabled.
          Please disable it first and then try again.")
        throw :abort
      end
      jobs.each { |j| j.destroy_children = true }
    end

    # check if client can be delete or not
    def destroyable
      jobs.complete_valid_jobs.count.zero? && !active
    end

    def generate_initials
      create_initials(Client, id, company_name)
    end
  end
end
