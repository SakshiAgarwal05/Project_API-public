module Fields
  # FieldsShareable
  module FieldsShareable
    def self.included(receiver)
      receiver.class_eval do
        belongs_to :job
        belongs_to :share_link
        belongs_to :talent
        belongs_to :user

        has_many :questionnaire_answers, as: :answerable, dependent: :destroy

        accepts_nested_attributes_for :questionnaire_answers
        alias_for_nested_attributes :questionnaire_answers=, :questionnaire_answers_attributes=
      end
    end
  end
end
