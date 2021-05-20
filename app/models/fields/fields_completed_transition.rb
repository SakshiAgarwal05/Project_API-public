module Fields
  # FieldsCompletedTransition
  module FieldsCompletedTransition
    def self.included(receiver)
      receiver.class_eval do
        belongs_to :talents_job, validate: false
        has_one :offer_letter
        has_one :offer_extension
        has_many :rtr, dependent: :destroy
        accepts_nested_attributes_for :offer_letter
        accepts_nested_attributes_for :offer_extension
        accepts_nested_attributes_for :rtr

        alias_for_nested_attributes :offer_letter=, :offer_letter_attributes=
        alias_for_nested_attributes :offer_extension=, :offer_extension_attributes=
        alias_for_nested_attributes :assignment_detail=, :assignment_detail_attributes=
        alias_for_nested_attributes :rtr=, :rtr_attributes=
        # attendees
        # has_and_belongs_to_many :users, autosave: true
        belongs_to :updated_by, polymorphic: true, validate: false
        belongs_to :event, validate: false
        delegate :job, to: :talents_job, allow_nil: true
        belongs_to :pipeline_step, validate: false
      end
    end
  end
end
