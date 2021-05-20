module Fields
  # FieldsTalent
  module FieldsTalent
    def self.included(receiver)

      receiver.class_eval do
        include Constants::ConstantsTalent
        include Fields::FieldsDeviseFields

        include Fields::FieldsTalentProfile

        # CSMM shared schema relation
        if ActiveRecord::Base.connection.table_exists? 'shared.csmm_scores'
          has_many :csmm_scores, validate: false
        end

        has_many :receivers, validate: false
        has_many :messages, through: :receivers, validate: false
        belongs_to :added_by, class_name: 'User', inverse_of: :created_talents
        belongs_to :hired_by, class_name: 'User', inverse_of: :hired_talents
        belongs_to :updated_by, polymorphic: true

        has_one :sourced_for_job, dependent: :destroy
        has_one :talent_preference

        has_many :event_attendees
        has_many :attend_events, through: :event_attendees
        has_many :events, as: :related_to
        has_many :identities, validate: true
        has_many :interview_slots
        has_many :notes, as: :notable, dependent: :destroy
        has_many :profiles, inverse_of: :talent, autosave: true, validate: false
        has_many :shareables, dependent: :destroy
        has_many :shared_jobs, through: :shareables, source: :job
        has_many :talents_jobs, class_name: 'TalentsJob'
        has_many :reminders, dependent: :destroy

        accepts_nested_attributes_for :interview_slots, allow_destroy: true
        accepts_nested_attributes_for :talent_preference, allow_destroy: true
        alias_for_nested_attributes :interview_slots=, :interview_slots_attributes=
        alias_for_nested_attributes :talent_preference=, :talent_preference_attributes=

        devise  :database_authenticatable,
                :registerable,
                :confirmable,
                :lockable,
                :recoverable,
                :rememberable,
                :trackable,
                :validatable,
                :omniauthable
      end
    end

    def resume_path
      SignedUrl.get(self['resume_path'])
    end

    def resume_path_pdf
      SignedUrl.get(self['resume_path_pdf'])
    end

    ########################
    public
    ########################

    def verified
      confirmed?
    end

    def enable
      locked_at.nil?
    end

    def start_date=(val)
      self.start_date = Date.parse(val) if val.is_a?(String)
    end

    def enable=(val)
      unlock_access! if [true, 'true'].include?(val)
      lock_access!(send_instructions: false) if [false, 'false'].include?(val)
    end

    def avatar
      avatar = self['avatar']
      return unless avatar
      image_resized ? avatar_100_public : SignedUrl.get(avatar)
    end


    ######################
    private
    ######################

    def init_currency
      self.current_currency_obj = Currency.find_by(abbr: current_currency).as_json(only: [:id, :abbr, :name]) if current_currency
      self.expected_currency_obj = Currency.find_by(abbr: expected_currency).as_json(only: [:id, :abbr, :name]) if expected_currency
    end
  end
end
