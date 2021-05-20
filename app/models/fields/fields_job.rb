module Fields
  # FieldsJob
  module FieldsJob
    def self.included(receiver)
      receiver.class_eval do
        cattr_accessor :current_talent

        # CSMM shared schema relation
        if ActiveRecord::Base.connection.table_exists? 'shared.csmm_scores'
          has_many :csmm_scores, validate: false
        end

        belongs_to :client, validate: false
        belongs_to :industry
        # belongs_to :contact
        belongs_to :updated_by, class_name: 'User'
        belongs_to :published_by, class_name: 'User'
        belongs_to :created_by, class_name: 'User'
        belongs_to :timezone
        belongs_to :category
        belongs_to :account_manager, class_name: 'User', validate: false
        belongs_to :onboarding_agent, class_name: 'User', validate: false
        belongs_to :supervisor, class_name: 'User', validate: false
        belongs_to :billing_term, validate: :false
        belongs_to :hiring_organization, validate: false
        belongs_to :hiring_manager, class_name: 'User', validate: false

        has_one :recruitment_pipeline, as: :embeddable
        has_one :onboarding_package, as: :embeddable
        has_one :questionnaire, as: :questionable
        has_many :talents_jobs, dependent: :destroy, validate: false
        has_many :notes, as: :notable, dependent: :destroy
        has_many :events, dependent: :destroy
        # has_many :associated_events, class_name: 'Event', inverse_of: :job
        has_many  :media,
                  as: :mediable,
                  after_remove: :send_destroy_notification
        # has_many :potential_earnings
        has_many :metrics_stages
        has_many :acknowledge_job_hold_users, dependent: :destroy

        has_many :affiliates, dependent: :destroy
        has_many :saved_affiliates, -> { where status: ['saved', 'archived'] },
                 class_name: 'Affiliate'

        has_many :accessible_jobs, dependent: :destroy
        has_many :exclusive_jobs, dependent: :destroy

        has_many :job_providers, dependent: :destroy
        has_many :recruiters_jobs, -> { where status: ['saved', 'archived'] }
        has_many  :picked_by,
                  through: :saved_affiliates,
                  source: :user

        has_many  :agencies_jobs
        has_many  :agencies, -> { distinct },
                  through: :agencies_jobs,
                  source: :agency

        has_many :invitations
        has_many  :invitees, -> { distinct },
                  through: :invitations,
                  source: :user

        has_and_belongs_to_many :skills

        has_many :distributions
        has_many :distributors, through: :distributions, source: :user

        has_one :probability_of_hire_stat
        has_one :static_poh
        has_one :standard_job_stat

        has_many :ho_jobs_watchers, dependent: :destroy
        has_many :hiring_watchers, through: :ho_jobs_watchers, source: :user

        has_many :badges

        has_many :badged_users, through: :badges, source: :user

        has_many :change_histories, as: :entity

        has_many :share_links, as: :shared, dependent: :destroy

        has_many :shareables, dependent: :destroy
        has_many :shared_talents, through: :shareables, source: :talent
        has_many :job_manual_invite_requests, dependent: :destroy

        has_one :job_similarity
        has_many :views

        accepts_nested_attributes_for :recruitment_pipeline, allow_destroy: true
        accepts_nested_attributes_for :questionnaire
        accepts_nested_attributes_for :onboarding_package
        accepts_nested_attributes_for :media, allow_destroy: true
        accepts_nested_attributes_for :job_providers

        alias_for_nested_attributes :recruitment_pipeline=, :recruitment_pipeline_attributes=
        alias_for_nested_attributes :questionnaire=, :questionnaire_attributes=
        alias_for_nested_attributes :onboarding_package=, :onboarding_package_attributes=
        alias_for_nested_attributes :media=, :media_attributes=
        alias_for_nested_attributes :job_providers=, :job_providers_attributes=

        attr_accessor :destroy_children, :skip_callback

        # Depricated in open-marketplace-1
        alias_attribute :partners, :agencies
        alias_attribute :partner_ids, :agency_ids
      end
    end

    def skill_ids=(val)
      fast_skill_ids_insert(val.reject(&:blank?))
    rescue
      super
    end

    def request_id
      job_providers.last&.uid
    end

    def max_applied_limit=(val)
      self['max_applied_limit'] = (val.to_i > 0 ? val : 'Unlimited')
    end

    def max_applied_limit
      self['max_applied_limit'].to_i > 0 ? self['max_applied_limit'].to_i : 0
    end

    def logo
      client.logo if client
    end

    def contact
      return nil unless contact_id
      client.contacts.find(contact_id)
    end

    def enable
      if !client || ['Scheduled', 'Draft'].include?(stage)
        return false
      end

      !locked_at && client.active?
    end

    # getter recruitment_pipeline_id
    def recruitment_pipeline_id
      @recruitment_pipeline_id
    end

    # setter recruitment_pipeline_id
    # copy data of recruitment pipeline from client to job.
    def recruitment_pipeline_id=(val)
      @recruitment_pipeline_id = val

      return if val.blank?

      ho = hiring_manager&.hiring_organization || billing_term&.hiring_organization
      return if ho.blank?

      rp = ho.recruitment_pipelines.find(val)

      if talents_jobs.count > 0
        errors.add(
          :base,
          'Can not change recruitment pipeline as recruitment is already started.
            You can edit this Recruitment Pipeline.'
        )
      end

      unless rp
        errors.add(:recruitment_pipeline, "doesn't belong to hiring_organization")
        return
      end

      if recruitment_pipeline.present?
        recruitment_pipeline.name = rp.name
        recruitment_pipeline.description = rp.description
      else
        self.recruitment_pipeline = build_recruitment_pipeline(
          rp.attributes.reject do |obj|
            %w(id pipeline_steps created_at updated_at copy).include?(obj)
          end
        )
      end

      recruitment_pipeline.copy = true

      if persisted? && recruitment_pipeline.pipeline_steps.exists?
        recruitment_pipeline.pipeline_steps.delete_all
      end

      rp.pipeline_steps.each do |step|
        recruitment_pipeline.pipeline_steps.build(
          step.attributes.select { |obj| obj != 'id' }
        )
      end
    end
  end
end
