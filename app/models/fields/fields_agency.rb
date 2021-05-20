module Fields
  module FieldsAgency
    def self.included(receiver)
      receiver.class_eval do
        belongs_to :created_by, class_name: 'User', inverse_of: :created_agency
        belongs_to :updated_by, class_name: 'User', inverse_of: :updated_agency
        has_many :talents_jobs, dependent: :destroy
        has_many :notes, as: :notable
        has_many :events, as: :related_to
        has_many :teams, dependent: :destroy
        has_many :users, dependent: :destroy
        has_many :metrics_stages, validate: false
        has_many :profiles, dependent: :destroy
        has_many :accessibles, dependent: :destroy
        has_many :affiliates, dependent: :destroy
        has_many :invitations, dependent: :destroy
        has_many :recruiters_jobs, dependent: :destroy
        has_many :accessible_jobs, dependent: :destroy
        has_many :exclusive_jobs, dependent: :destroy
        has_many :share_links, dependent: :destroy

        has_many  :agencies_jobs
        has_many  :jobs, -> { distinct },
                  through: :agencies_jobs,
                  source: :job
        has_and_belongs_to_many :clients

        has_and_belongs_to_many :exclusive_billing_terms, class_name: 'BillingTerm',
                                                          validate: :false

        accepts_nested_attributes_for :users, allow_destroy: true
        accepts_nested_attributes_for :accessibles, allow_destroy: true

        alias_for_nested_attributes :users=, :users_attributes=
        alias_for_nested_attributes :accessibles=, :accessibles_attributes=
      end
    end

    def users_count
      users.count
    end

    def logo
      logo = self['logo']
      return unless logo
      image_resized ? logo_100_public : SignedUrl.get(logo)
    end
  end
end
