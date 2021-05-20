module Validations
  module ValidationsTalent

    def self.included(receiver)
      receiver.class_eval do
        validates :first_name, :last_name, :country, :state,
                  :postal_code, :city, presence: true
        validate :add_detailed_errors, on: :create, if: proc { |obj| obj.errors.empty? }
        validate :validate_country_state_and_city, unless: proc { |x| x.country.blank? }
        validates :username, uniqueness: {if: :username}
        validates :summary, html_content_length: { maximum: 5000 }
        validates :sin, length: { maximum: 4 }
        validate :if_lockable
        validates :languages,validate_uniqueness_in_memory: {
          message: 'Duplicate languages selected.',
          uniq_attr: :name,
          attrs: [:embeddable_id, :embeddable_type]
        }
        validate :atleast_one_primary_email
        validate :format_of_resume_path
        validates :industries, validate_maximum_limit: {limit: 5}
        validate :validate_password
        validate :validate_dnd, on: :update
      end
    end

    ########################
    private
    ########################

    # A candidate can not be disabled if it is already in recruitment process.
    def if_lockable
      return unless self.changed.include?("locked_at")
      if self.talents_jobs.active.count > 0
        job_list = self.talents_jobs.active.collect{|tj| "<a href='/#/job-marketplace/#{tj.job_id}'>#{tj.job.title}</a>"}.join(', ')
        self.errors.add(:base, "You cannot disable #{self.name} because they are currently in the hiring process for #{job_list}")
      end
    end

    def format_of_resume_path
      return unless changed.include?('resume_path')
      accepted_formats = Resume::ACCEPTABLE_RESUME_FORMATS
      self.errors.add(:base, 'This format of resume is not acceptable. Please add some other format.') unless accepted_formats.include? File.extname(self['resume_path'])
    end

    def validate_dnd
      return unless changed.include?('contact_by_phone') || changed.include?('contact_by_email')

      return if contact_by_phone? && contact_by_email?

      return if talents_jobs.not_withdrawn.empty?

      errors.add(
        :base,
        "#{name} is currently engaged in #{talents_jobs.not_withdrawn.count} active jobs.
          Please withdraw them and try again."
      )
    end
  end
end
