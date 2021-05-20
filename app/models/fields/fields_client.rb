module Fields
  # FieldsClient
  module FieldsClient
    def self.included(receiver)
      receiver.class_eval do
        # as_json doesn't except parameters. so to set current parameter
        # current_user attribute accessors is created.
        # need to set it every time when want to fetch the powers/permissions
        # for current user

        # there are 3 fields for client with little difference
        # * active: set by super admin to activate or deactivate a client.

        # fields related to billing profile
        belongs_to :timezone
        belongs_to :industry
        belongs_to :created_by, class_name: 'User'
        belongs_to :resume_template

        has_many :media, as: :mediable
        has_many :links, as: :embeddable
        has_many :contacts, as: :contactable
        has_many :rejected_histories
        has_many :jobs, dependent: :destroy, validate: false
        has_many :notes, as: :notable, dependent: :destroy, validate: false
        has_many :events
        # has_many :associated_events, class_name: 'Event', foreign_key: :client_id
        has_many :talents_jobs
        has_many  :users,
                  class_name: 'User',
                  inverse_of: :client,
                  dependent: :destroy,
                  validate: false

        has_many :hiring_organizations
        has_many :billing_terms
        has_many :recruitment_pipelines, as: :embeddable
        has_many :onboarding_packages, as: :embeddable
        has_many :metrics_stages
        has_many :saved_clients_users
        has_many :saved_by, through: :saved_clients_users, source: :user
        has_many :assignables
        has_many :shared_users, through: :assignables, source: :user
        has_many :accessibles, validate: false, dependent: :destroy

        has_and_belongs_to_many :agencies

        accepts_nested_attributes_for :links, allow_destroy: true
        accepts_nested_attributes_for :media, allow_destroy: true
        accepts_nested_attributes_for :contacts, allow_destroy: true
        accepts_nested_attributes_for :users, allow_destroy: true
        accepts_nested_attributes_for :assignables, allow_destroy: true

        # Depricated in open-marketplace-1
        alias_attribute :partners, :agencies
        alias_attribute :partner_ids, :agency_ids

        alias_for_nested_attributes :links=, :links_attributes=
        alias_for_nested_attributes :media=, :media_attributes=
        alias_for_nested_attributes :contacts=, :contacts_attributes=
        alias_for_nested_attributes :users=, :users_attributes=
        alias_for_nested_attributes :assignables=, :assignables_attributes=
      end
    end

    def logo
      logo = self['logo']
      return unless logo
      image_resized ? logo_100_public : SignedUrl.get(logo)
    end
  end
end
