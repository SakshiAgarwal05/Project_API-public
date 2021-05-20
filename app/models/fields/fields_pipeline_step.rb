module Fields
  module FieldsPipelineStep
    def self.included(receiver)
      receiver.class_eval do
        belongs_to :recruitment_pipeline
        has_many :completed_transitions
        attr_accessor :skip_metrics_update
      end

    end
  end
end
