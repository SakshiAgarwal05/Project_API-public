module Fields
  # FieldsOnboard
  module FieldsOnboard
    def self.included(receiver)
      receiver.class_eval do
        # field :onboarding_document_id, type: String
        # field :action_completed, type: Mongoid::Boolean, default: false
        # field :status, type: String, default: 'pending'
        # field :file, type: String

        has_many :rejected_histories
        belongs_to :talents_job
        delegate :job, :to => :talents_job, :allow_nil => true
        belongs_to :onboarding_document
      end
    end

    def file
      SignedUrl.get(self['file'])
    end

    def onboarding_document_json
      onboarding_document.as_json
    end
  end
end
