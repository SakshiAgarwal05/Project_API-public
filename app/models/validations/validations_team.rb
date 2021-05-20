module Validations
  # ValidationsTeam
  module ValidationsTeam
    def self.included(receiver)
      receiver.class_eval do
        validates :name, :agency_id, :created_by, presence: true
        validates :name, uniqueness: { scope: :agency_id }
        validate :presence_of_group_member
      end
    end

    ################
    private
    ###############

    # at least one group member is required for creating a group
    def presence_of_group_member
      if !user_ids.size.zero? || !changed.exclude?('locked_at')
        return
      end

      errors.add(:base, "Group #{name} should have atleast one member")
    end
  end
end
