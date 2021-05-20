module Fields
  # FieldsHiringOrganization
  module FieldsHiringOrganization
    def self.included(receiver)
      receiver.class_eval do
        belongs_to :client
        belongs_to :created_by, class_name: 'User'

        has_many :contacts, as: :contactable
        has_many :billing_contacts, class_name: 'Contact'
        has_many :billing_terms
        has_many :jobs, validate: false
        has_many :recruitment_pipelines, as: :embeddable
        has_many :onboarding_packages, as: :embeddable
        has_many :talents_jobs, validate: false
        has_many :metrics_stages
        has_many :users
        has_many :groups
        has_many :profiles, dependent: :destroy

        accepts_nested_attributes_for :contacts, allow_destroy: true
        alias_for_nested_attributes :contacts=, :contacts_attributes=

        accepts_nested_attributes_for :billing_contacts, allow_destroy: true
        alias_for_nested_attributes :billing_contacts=, :billing_contacts_attributes=

        accepts_nested_attributes_for :recruitment_pipelines, allow_destroy: true
        alias_for_nested_attributes :recruitment_pipelines=, :recruitment_pipelines_attributes=

        accepts_nested_attributes_for :onboarding_packages, allow_destroy: true
        alias_for_nested_attributes :onboarding_packages=, :onboarding_packages_attributes=

        accepts_nested_attributes_for :users, allow_destroy: true
        alias_for_nested_attributes :users=, :users_attributes=
      end
    end

    def logo
      return client.logo if direct?

      logo = self['logo']
      return unless logo
      image_resized ? logo_100_public : SignedUrl.get(logo)
    end
  end
end
