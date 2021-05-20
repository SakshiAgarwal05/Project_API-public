module Validations
  # ValidationsGroup
  module ValidationsGroup
    def self.included(receiver)
      receiver.class_eval do
        validates :name, :hiring_organization_id, :description, presence: true
        validates :name, uniqueness: { scope: :hiring_organization_id }
        validate :presence_of_group_member
        validates :description, length: { maximum: 180 }, allow_blank: true
      end
    end

    private

    # at least one group member is required for creating a group
    def presence_of_group_member
      if !user_ids.size.zero? || !changed.exclude?('locked_at')
        return
      end

      errors.add(:base, "Group #{name} should have atleast one member")
    end
  end
end
