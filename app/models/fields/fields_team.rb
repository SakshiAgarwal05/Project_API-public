module Fields
  # FieldsTeam
  module FieldsTeam
    def self.included(receiver)
      receiver.class_eval do

        belongs_to :agency, validate: false
        belongs_to :timezone
        belongs_to :created_by, class_name: 'User',
                                inverse_of: :created_teams
        belongs_to :updated_by, class_name: 'User',
                                inverse_of: :updated_teams

        has_many :notes, as: :notable
        has_many :events, as: :related_to

        has_many :teams_users, dependent: :destroy, validate: false
        has_many :users, through: :teams_users, source: :user, validate: false

        accepts_nested_attributes_for :users, allow_destroy: true
        alias_for_nested_attributes :users=, :users_attributes=

        # Depricated in open-marketplace-1
        alias_attribute :partner, :agency
        alias_attribute :partner_id, :agency_id
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
