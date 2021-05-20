module Validations
  module ValidationsQuestion
    def self.included(receiver)
      receiver.class_eval do
        validates :question,
                  presence: true,
                  unless: proc { |obj| obj.type_of_question.eql?('PAGE_BREAK') }

        validates :options,
                  presence: true,
                  if: proc { |obj| Question::OPTIONAL.exclude?(obj.type_of_question) }

        validates :question,
                  uniqueness: { scope: [:questionnaire_id, :type_of_question, :removed] },
                  if: proc { |obj| obj.questionnaire&.persisted? },
                  unless: proc { |obj| obj.type_of_question.eql?('PAGE_BREAK') },
                  allow_blank: true
      end
    end
  end
end
