module Fields
  # FieldsRecruitmentPipeline
  module FieldsRecruitmentPipeline
    def self.included(receiver)
      receiver.class_eval do
        attr_accessor :copy
        # field :name, type: String
        # field :description, type: String

        # embedded in hiring organization, client and job. whenever a job selects a recruitment pipeline from client it will create duplicate record for job.
        belongs_to :embeddable, polymorphic: true

        has_many :pipeline_steps, validate: true, dependent: :destroy
        accepts_nested_attributes_for :pipeline_steps, allow_destroy: true
        alias_for_nested_attributes :pipeline_steps=, :pipeline_steps_attributes=
        belongs_to :created_by, class_name: 'User'
        belongs_to :updated_by, class_name: 'User'
      end
    end
  end
end
