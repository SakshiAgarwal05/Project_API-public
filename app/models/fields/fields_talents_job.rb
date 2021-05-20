module Fields
  # FieldsTalentsJob
  module FieldsTalentsJob
    def self.included(receiver)
      receiver.class_eval do
        attr_accessor :if_auto_withdrawn
        attr_accessor :invited
        attr_accessor :event_id
        attr_accessor :updated_by_id, :updated_by_type

        belongs_to :job, validate: false
        belongs_to :talent, validate: false
        belongs_to :agency, validate: false
        belongs_to :user, validate: false
        belongs_to :rejected_by, polymorphic: true
        belongs_to :reinstate_by, polymorphic: true
        belongs_to :withdrawn_by, polymorphic: true
        belongs_to :profile, validate: false
        belongs_to :client, validate: false
        belongs_to :hiring_organization, validate: false
        belongs_to :billing_term, validate: false
        has_many :completed_transitions, dependent: :destroy
        has_many :mentioned_users, dependent: :destroy
        accepts_nested_attributes_for :completed_transitions
        alias_for_nested_attributes :completed_transitions=, :completed_transitions_attributes=
        has_many :metrics_stages, dependent: :destroy
        has_many :onboards, dependent: :destroy
        has_many :favorites, dependent: :destroy
        has_many :pipeline_notifications, dependent: :destroy
        has_many :questionnaire_answers, as: :answerable, dependent: :destroy
        accepts_nested_attributes_for :questionnaire_answers
        alias_for_nested_attributes :questionnaire_answers=, :questionnaire_answers_attributes=
        has_many :events, as: :related_to, dependent: :destroy
        has_many :notes, as: :notable, dependent: :destroy

        has_many  :all_rtr,
                  -> { order 'created_at ASC' },
                  class_name: 'Rtr',
                  dependent: :destroy

        has_many  :all_offer,
                  -> { order 'created_at ASC' },
                  class_name: 'OfferLetter',
                  dependent: :destroy

        has_many  :all_offer_extensions,
                  -> { order 'created_at ASC' },
                  class_name: 'OfferExtension',
                  dependent: :destroy

        has_many :talents_jobs_resumes, dependent: :destroy
        has_many :resumes, as: :uploadable, dependent: :destroy
        has_many :acknowledge_disqualified_users, dependent: :destroy
        has_many :acknowledge_disqualified_by, through: :acknowledge_disqualified_users, source: :user
        #while deleting check if it is attached to talents_job or talent and delete only if attached to talents_job
        has_many :attached_resumes, through: :talents_jobs_resumes, source: :resume, dependent: :destroy
        has_one :assignment_detail
        accepts_nested_attributes_for :assignment_detail, allow_destroy: true
        alias_for_nested_attributes :assignment_detail=, :assignment_detail_attributes=

        accepts_nested_attributes_for :resumes
        alias_for_nested_attributes :resumes=, :resumes_attributes=
        # Depricated in open-marketplace-1
        alias_attribute :partner, :agency
        alias_attribute :partner_id, :agency_id
        alias :questionnaire_answers= :questionnaire_answers_attributes=
      end
    end

    def email=(val)
      self[:email] = val ? val.downcase : val
    end

    # Soft deleted talent reading from Profile model.
    def talent
      return super if new_record?
      super || (profile ? profile.talent : nil)
    end

    def sin
      questionnaire_answers.find_by(question: 'What is your last four digit of SIN?')&.talent_answer
    end

    alias_method :social_security_number, :sin

    def dob
      questionnaire_answers.find_by(question: 'What is your date of birth?')&.talent_answer || '-'
    end

    alias_method :date_of_birth, :dob
  end
end
