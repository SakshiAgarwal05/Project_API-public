# common fields for talents and users
module Fields
  module FieldsDeviseFields

    def self.included(receiver)
      receiver.class_eval do
        attr_accessor :login
      end
    end
  end
end
