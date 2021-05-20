module Fields
  # FieldsProfile
  module FieldsProfile
    def self.included(receiver)
      receiver.class_eval do
        include Fields::FieldsTalentProfile
        # user as well as talent can have many copies of profile.
        # Everytime a job is saved it will create a copy of profile.

        belongs_to :profilable, polymorphic: true, autosave: true, validate: false
        belongs_to :talent, -> { with_deleted }, autosave: true, inverse_of: :profiles,
          validate: false
        belongs_to :agency
        belongs_to :hiring_organization, validate: false

        has_one :talents_job, validate: false
        has_one :reminder, dependent: :destroy

        has_many :taggings, as: :taggable, dependent: :destroy
        has_many :tags, through: :taggings
      end
    end

    def talent
      Talent.unscoped { super }
    end
  end
end
