module Scopes
  module ScopesPipelineStep
    def self.included(receiver)
      receiver.class_eval do
        default_scope -> {order("stage_order asc")}
      end
    end
  end
end