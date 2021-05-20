module Scopes
  module ScopesRecruitmentPipeline
    def self.included(receiver)
      receiver.class_eval do
        scope :global, ->{where(global: true)}
      end
    end


    ########################
    private
    ########################

  end
end
