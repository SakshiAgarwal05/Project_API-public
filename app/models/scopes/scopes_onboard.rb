module Scopes
  module ScopesOnboard
    def self.included(receiver)
      receiver.class_eval do
        scope :not_approved, -> {where.not(status: "approved")}
        scope :completed, -> {where(action_completed: true)}
        scope :approved, -> {where(status: "approved")}
      end
    end


    ########################
    private
    ########################

  end
end
