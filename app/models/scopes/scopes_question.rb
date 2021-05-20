module Scopes
  module ScopesQuestion
    def self.included(receiver)
      receiver.class_eval do
        scope :shared, -> { where(is_shared: true) }
      end
    end
  end
end
