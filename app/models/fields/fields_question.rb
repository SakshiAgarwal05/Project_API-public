module Fields
  module FieldsQuestion
    def self.included(receiver)
      receiver.class_eval do
        belongs_to :questionnaire
        belongs_to :user

        has_many :questions_templates, dependent: :delete_all
        has_many :templates, through: :questions_templates

        has_many :taggings, as: :taggable, dependent: :delete_all
        has_many :tags, through: :taggings
      end
    end
  end
end
