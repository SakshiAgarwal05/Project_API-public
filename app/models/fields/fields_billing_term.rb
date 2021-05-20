module Fields
  # FieldsBillingTerm
  module FieldsBillingTerm
    def self.included(receiver)
      receiver.class_eval do
        enum billing_type: [:bill_rate, :markup]

        attr_accessor :agency_value_old_ids

        belongs_to :client
        belongs_to :created_by, class_name: 'User'
        belongs_to :ats_platform, touch: true
        belongs_to :msp_name, touch: true
        belongs_to :vms_platform, touch: true
        belongs_to :proprietary_platform, touch: true
        belongs_to :hiring_organization, validate: false

        has_many :jobs, validate: false
        has_many :talents_jobs, validate: false
        has_many :metrics_stages

        has_and_belongs_to_many :categories
        has_and_belongs_to_many :countries
        has_and_belongs_to_many :states
        has_and_belongs_to_many :agencies

        accepts_nested_attributes_for :vms_platform
        accepts_nested_attributes_for :ats_platform
        accepts_nested_attributes_for :msp_name
        accepts_nested_attributes_for :proprietary_platform
        alias_for_nested_attributes :vms_platform=, :vms_platform_attributes=
        alias_for_nested_attributes :ats_platform=, :ats_platform_attributes=
        alias_for_nested_attributes :msp_name=, :msp_name_attributes=
        alias_for_nested_attributes :proprietary_platform=, :proprietary_platform_attributes=
      end
    end
  end
end
