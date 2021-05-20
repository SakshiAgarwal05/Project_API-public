module Validations
  # ValidationsJob
  module ValidationsJob
    def self.included(receiver)
      receiver.class_eval do
        validate :job_type_editable

        validates :title, :client, :hiring_organization,
                  :type_of_job, presence: true

        validates :billing_term,
                  presence: true,
                  unless: proc { |obj| obj.created_by&.hiring_org_user? }

        validates :responsibilities, :title, :address, :city,
                  :state, :country, :positions, :summary, :pay_period, :currency,
                  :years_of_experience, :category, :job_id, :recruitment_pipeline,
                  :start_date, :postal_code,
                  presence: true, if: :is_being_published?

        validates :duration_period, presence: true,
                                    if: proc { |obj| obj.published_at && obj.contract? }

        validates :summary, :responsibilities, :minimum_qualification,
                  :preferred_qualification, :additional_detail,
                  html_content_length: { maximum: 10000 }

        validates :suggested_pay_rate, presence: true,
                  if: proc { |obj| obj.published_at }

        validates :duration,
                  numericality: { greater_than: 0 },
                  if: proc { |obj| obj.published_at && obj.contract? }

        validates :positions,
                  numericality: { only_integer: true, greater_than: 0, allow_blank: true },
                  if: proc { |obj| obj.published_at }

        validates :stage, inclusion: {
          in: Job::ALL_STAGES,
        }, allow_blank: true

        validates :type_of_job, inclusion: {
          in: Job::TYPES_OF_JOB,
        }, allow_blank: true

        validates :location_type, inclusion: {
          in: Job::LOCATION_TYPES,
        }, allow_blank: true

        validates :job_id, uniqueness: { scope: :client }, allow_blank: true

        validates :duration_period, :pay_period,
                  inclusion: { in: %w(years months days hours weeks) },
                  allow_blank: true

        # validate :presence_of_skills
        Job::JOB_STAGE_NOTES.each do |key, val|
          validates key, presence: true, if: proc { |obj| obj.try(val) }
        end

        # getting error message while creating a job and so added !t.is_onhold_was.nil? - surat
        validates :reason_to_unhold_job,
                  presence: true,
                  if: proc { |obj|
                        !obj.is_onhold_was.nil? &&
                          obj.changed.include?('is_onhold') &&
                          !obj.is_onhold &&
                          obj.persisted?
                      }

        validate :publish_date

        validate :validate_country_state_and_city,
                 if: proc { |obj| obj.published_at.present? }

        validate :if_editable?

        validate :check_client

        validate :can_change_pipeline,
                 if: proc { |obj|
                       obj.recruitment_pipeline_id != (begin
                                                         obj.recruitment_pipeline.id
                                                       rescue
                                                         nil
                                                       end)
                     }

        validate :check_stage

        validate :validation_at_offer_stage

        validate :max_applicants_on_hold

        validate :on_job_status_change,
                 if: proc { |obj| (obj.changed.include?('stage') && obj.is_closed?) }

        validate :check_job_users, unless: proc { |job| job.is_closed? }

        validate :if_can_unhold

        validate :number_of_filled_positions
      end
    end

    ########################

    private

    ########################

    def if_can_unhold
      cant_unhold = changed.include?('is_onhold') && is_onhold.is_false? && holdable?
      errors.add(:base, I18n.t('job.error_messages.reached_max_applied_limit')) if cant_unhold
    end

    def max_applicants_on_hold
      return unless changed.include?('max_applied_limit')
      return unless total_active_applied_count >= max_applied_limit

      if max_applied_limit.zero?
        update_column(:max_applied_limit, (positions * 10))
      else
        errors.add(:base, I18n.t('job.error_messages.reached_max_applied_limit'))
      end
    end

    def validation_at_offer_stage
      offer_tjs = talents_jobs.by_stage('Offer', false)
      return unless changed.include?('stage') && is_closed? && talents_jobs.count > 0 && offer_tjs.count > 0

      candidates = offer_tjs.collect { |x| x.talent&.name }.join(',')
      errors.add(
        :base,
        I18n.t('job.error_messages.offer_stage_no_close', stage: stage, candidates: candidates)
      )
    end

    # Once a job is open the type of job is not editable
    def job_type_editable
      return unless changed.include?('type_of_job') && published?
      errors.add(:type_of_job, I18n.t('job.error_messages.not_editable'))
    end

    # job Publish date must be less than start_date
    def publish_date
      return if published_at.nil? || start_date.nil? || published_at <= start_date.end_of_day
      errors.add(
        :published_at,
        "should be less than start date. Your start date has been set as
        #{start_date.to_date}, which should be actually after #{published_at.to_date}.
        Please edit start date first."
      )
    end

    # can not change recruitment pipeline if a candidate is already sourced to it.
    def if_editable?
      return unless changed.include?('recruitment_pipeline') && talents_jobs.count > 0
      errors.add(:recruitment_pipeline,
                 'is not editable. Recruitment process is already initiated for this job.')
    end

    # check if client is active or not.
    def check_client
      return if client.nil?
      errors.add(:base, 'client is not active') unless client.active
    end

    # can not change a pipeline if job is published.
    def can_change_pipeline
      return unless published? && changed.include?(:recruitment_pipeline_id)
      errors.add(:base, 'You can only edit pipeline. You can not change it.')
    end

    # checks if someone can enable / disable the job or not.
    def check_stage
      return unless (changed & %w(stage published_at)).empty?
      return unless changed.include?('locked_at')
      if enable
        # check if someone can enable or not
        errors.add(:base, I18n.t('job.error_messages.cant_enable_draft_job')) unless published?
      else
        # check if someone can disable or not
        return if talents_jobs.not_withdrawn.count.zero?
        errors.add(:base, I18n.t('job.error_messages.cant_disable_active_job'))
      end
    end

    def on_job_status_change
      return if changes["stage"].last.eql?('Closed')
      errors.add(:base, I18n.t('job.error_messages.valid_job')) unless complete_valid_job
    end

    def check_job_users
      return if client.nil? && (changed & %w(account_manager_id onboarding_agent_id)).empty?
      if account_manager && !is_account_manager?(account_manager)
        errors.add(
          :account_manager,
          I18n.t('job.error_messages.not_belong_to_client', company_name: client.company_name)
        )
      end

      return if onboarding_agent.nil? ||
                (onboarding_agent && is_onboarding_agent?(onboarding_agent))
      errors.add(
        :onboarding_agent,
        I18n.t('job.error_messages.not_belong_to_client', company_name: client.company_name)
      )
    end

    def is_being_published?
      published_at && !hiring_organization&.strategic_partner?
    end

    def number_of_filled_positions
      return unless changed.include?('stage') && changed.include?('filled_positions') && stage.eql?('Closed')
      if filled_positions
        if filled_positions <= 0
          errors.add(:base, 'The number of hires should be greater than 0.')
        elsif filled_positions > positions.to_i
          errors.add(:base, 'The number of hires cannot exceed the number of positions for the job.')
        end
      end
    end
  end
end
