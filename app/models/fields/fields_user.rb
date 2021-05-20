module Fields
  # FieldsUser
  module FieldsUser
    def self.included(receiver)
      receiver.class_eval do
        devise  :database_authenticatable,
                :registerable,
                :confirmable,
                :lockable,
                :recoverable,
                :rememberable,
                :trackable,
                :validatable,
                authentication_keys: [:login]

        attr_accessor :ip

        # BelongsTo Association order by Alphabetically ascending.
        belongs_to :agency, validate: false
        belongs_to :client
        belongs_to :created_by, class_name: 'User', foreign_key: :created_by_id
        belongs_to :hiring_organization, validate: false
        belongs_to :updated_by, class_name: 'User', foreign_key: :updated_by_id
        belongs_to :timezone

        # HasMany Association order by Alphabetically ascending.
        has_many :accessible_jobs, dependent: :destroy
        has_many :acknowledge_job_hold_users, dependent: :destroy
        has_many :affiliates, dependent: :destroy
        has_many :change_histories, foreign_key: :user_id

        has_many :created_affiliates, foreign_key: :created_by_id
        has_many :created_agency, class_name: 'Agency', foreign_key: :created_by_id

        has_many :created_billing_terms,
                 class_name: 'BillingTerm',
                 foreign_key: :created_by_id,
                 validate: false

        has_many :created_clients, class_name: 'Client', foreign_key: :created_by_id
        has_many :created_groups, class_name: 'Group', foreign_key: :created_by_id

        has_many :created_hiring_organizations,
                 class_name: 'HiringOrganization',
                 foreign_key: :created_by_id,
                 validate: false

        has_many :created_jobs, class_name: 'Job', foreign_key: :created_by_id

        has_many :created_pipeline_notifications,
                 class_name: 'PipelineNotification',
                 foreign_key: :created_by_id,
                 dependent: :destroy

        has_many :created_questions, class_name: 'Question', dependent: :nullify, validate: false

        has_many :created_reminders,
                 class_name: 'Reminder',
                 foreign_key: :created_by_id,
                 dependent: :destroy

        has_many :created_talents, class_name: 'Talent', foreign_key: :added_by_id
        has_many :created_teams, class_name: 'Team', foreign_key: :created_by_id
        has_many :created_templates, class_name: 'Template', dependent: :nullify, validate: false
        has_many :created_users, class_name: 'User', foreign_key: :created_by_id

        if ActiveRecord::Base.connection.table_exists? 'shared.csmm_scores'
          has_many :csmm_scores, validate: false
        end

        has_many :approved_bill_rate_negotiations,
                 class_name: 'BillRateNegotiation', foreign_key: :approved_by_id
        has_many :emails, as: :mailable, validate: false
        has_many :exclusive_jobs, dependent: :destroy
        has_many :event_created, class_name: 'Event', foreign_key: :user_id
        has_many :events, through: :event_attendees
        has_many :event_attendees
        has_many :given_notes, class_name: 'Note'
        has_many :hiring_jobs, class_name: 'Job', foreign_key: :hiring_manager_id
        has_many :hired_talents, class_name: 'Talent', foreign_key: :hired_by_id
        has_many :managed_jobs, class_name: 'Job', foreign_key: :account_manager_id
        has_many :mentioned_users, dependent: :destroy
        has_many :messages, through: :receivers, validate: false
        has_many :metrics_stages, validate: false
        has_many :notes, as: :notable, validate: false
        has_many :onboard_jobs, class_name: 'Job', foreign_key: :onboarding_agent_id
        has_many :phones, as: :callable, validate: false
        # has_many :potential_earnings
        has_many :profiles, as: :profilable, autosave: true, validate: false
        has_many :proposed_bill_rate_negotiations,
                 class_name: 'BillRateNegotiation', foreign_key: :proposed_by_id
        has_many :published_jobs, class_name: 'Job', foreign_key: :published_by_id
        has_many :receivers, validate: false
        has_many :recruiter_metrics_stages, class_name: 'MetricsStage', foreign_key: :recruiter_id

        has_many :recruiters_jobs
        has_many :rejected_bill_rate_negotiations,
                 class_name: 'BillRateNegotiation', foreign_key: :rejected_by_id
        has_many :reminders, dependent: :destroy
        has_many :sd_scores, class_name: 'SdScore', foreign_key: :recruiter_id
        has_many :shareables, dependent: :destroy
        has_many :supervisord_jobs, class_name: 'Job', foreign_key: :supervisor_id
        has_many :talents_jobs, validate: false
        has_many :updated_agency, class_name: 'Agency', foreign_key: :updated_by_id
        has_many :updated_jobs, class_name: 'Job', foreign_key: :updated_by_id
        has_many :updated_teams, class_name: 'Team', foreign_key: :updated_by_id
        has_many :updated_users, class_name: 'User', foreign_key: :updated_by_id

        # HasMany & Through Association order ascending
        has_many :assignables
        has_many :clients, through: :assignables

        has_many :acknowledge_disqualified_users, dependent: :destroy
        has_many :acknowledge_disqualified_candidates,
                 through: :acknowledge_disqualified_users,
                 source: :note

        has_many :badges, dependent: :destroy
        has_many :badged_jobs, through: :badges, source: :job

        has_many :distributions, dependent: :destroy
        has_many :distributed_jobs, through: :distributions, source: :job

        has_many :groups_users
        has_many :groups, through: :groups_users

        has_many :ho_jobs_watchers, dependent: :destroy
        has_many :watching_jobs, through: :ho_jobs_watchers, source: :job

        has_many :invitations
        has_many :invited_jobs, -> { distinct }, through: :invitations

        has_many :mentioned_notes_users, dependent: :destroy
        has_many :mentioned_in, through: :mentioned_notes_users, source: :note

        has_many :read_notes_users, dependent: :destroy
        has_many :read_notes, through: :read_notes_users, source: :note

        has_many :read_offer_letters_users, dependent: :destroy
        has_many :read_offer, through: :read_offer_letters_users, source: :offer_letter

        has_many :read_bill_rates
        has_many :read_rate, through: :read_bill_rates, source: :user

        has_many :saved_clients_users
        has_many :saved_clients, through: :saved_clients_users, source: :client

        has_many :saved_jobs, -> { where(status: ['saved', 'archived']) }, class_name: 'Affiliate'
        has_many :jobs, through: :saved_jobs

        has_many :users_reminders, dependent: :destroy, validate: false
        has_many :tagged_reminders, through: :users_reminders, source: :reminder, validate: false

        has_many :teams_users, dependent: :destroy, validate: false
        has_many :teams, through: :teams_users, source: :team, validate: false

        # HABTM Association order ascending
        has_and_belongs_to_many :categories
        has_and_belongs_to_many :countries

        has_and_belongs_to_many :industries,
                                join_table: :industries_users,
                                validate: false

        has_and_belongs_to_many :positions
        has_and_belongs_to_many :skills

        has_many :job_manual_invite_requests, dependent: :destroy
        # Accepts nested attributes and alias for them.
        accepts_nested_attributes_for :agency
        alias_for_nested_attributes :agency=, :agency_attributes=

        accepts_nested_attributes_for :assignables, allow_destroy: true
        alias_for_nested_attributes :assignables=, :assignables_attributes=

        accepts_nested_attributes_for :phones, allow_destroy: true
        alias_for_nested_attributes :phones=, :phones_attributes=

        accepts_nested_attributes_for :emails, allow_destroy: true
        alias_for_nested_attributes :emails=, :emails_attributes=

        accepts_nested_attributes_for :hiring_organization, allow_destroy: true
        alias_for_nested_attributes :hiring_organization=, :hiring_organization_attributes=

        # Depricated in open-marketplace-1
        alias_attribute :partner, :agency
        alias_attribute :partner_id, :agency_id
        alias :partner= :agency=
        alias_attribute :cs_email, :email
        attr_accessor :score
        attr_accessor :request_recommendations
      end
    end

    def skill_ids=(val)
      begin
        fast_skill_ids_insert(val.reject(&:blank?))
      rescue
        super
      end
    end

    def industry_ids=(val)
      begin
        fast_industry_ids_insert(val.reject(&:blank?))
      rescue
        super
      end
    end

    def category_ids=(val)
      begin
        fast_category_ids_insert(val.reject(&:blank?))
      rescue
        super
      end
    end

    def country_ids=(val)
      begin
        fast_country_ids_insert(val.reject(&:blank?))
      rescue
        super
      end
    end

    def avatar
      avatar = self['avatar']
      return unless avatar
      image_resized ? avatar_100_public : SignedUrl.get(avatar)
    end

    def enable
      if agency_user?
        agency&.enabled && locked_at.nil? && confirmed?
      elsif hiring_org_user?
        hiring_organization&.enable && locked_at.nil? && confirmed?
      else
        locked_at.nil? && confirmed?
      end
    end

    def enable=(val)
      return unless confirmed?
      unlock_access! if val.is_true?
      lock_access!(send_instructions: false) if val.is_false?
    end
  end
end
