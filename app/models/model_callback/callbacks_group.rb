module ModelCallback
  module CallbacksGroup
    def self.included(receiver)
      receiver.class_eval do
        before_destroy :check_team_members
      end
    end

    ########################
    private

    ########################

    def check_team_members
      return if users.count.zero?
      errors.add(:base, 'To delete the group you must first remove all members of the group')
      throw :abort
    end
  end
end
