module Validations
  # ValidationsOnboard
  module ValidationsOnboard
    def self.included(receiver)
      receiver.class_eval do
        validates :status, inclusion: { in: Onboard::STATUS }
        # validate :if_rejected
      end
    end

    ########################
    private
    ########################

    # def if_rejected
    #   return if status == "approved" && action_completed
    #   self.errors.add(:base, "Talent hasn't update new document.")
    # end
  end
end
