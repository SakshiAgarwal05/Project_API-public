module ModelCallback
  module CallbacksTeam
    def self.included(receiver)
      receiver.class_eval do
        before_destroy :check_team_members
        before_validation :init_address
        after_save :member_change_email, if: Proc.new{|p| p.changed.include?("user_ids")}
        before_destroy :if_disabled
        before_save :add_company_name
      end
    end


    ########################
    private
    ########################

    def if_disabled
      return true unless enabled
      errors.add(:base, "Can't delete a enabled team.")
      throw :abort
    end

    def check_team_members
      return if users.count.zero?
      errors.add(:base, 'To delete the group you must first remove all members of the group')
      throw :abort
    end

    # email users if they are removed or added in a team.
    def member_change_email
      deleted_users = User.find(((user_ids_was||[]) - (user_ids||[])))
      new_users = User.find(((user_ids||[]) - (user_ids_was||[])))
    end

    def add_company_name
      self.company_name = agency.company_name
    end
  end
end
