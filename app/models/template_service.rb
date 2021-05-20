class TemplateService
  class << self
    def load_default_questions
      [
        { type_of_question: 'PAGE_BREAK' },

        {
          question: "Are you authorized to work in the United States?",
          options: [{ value: 'Yes' }, { value: 'No' }],
          type_of_question: 'DROPDOWN',
        },

        {
          question: 'If yes, what is your work visa status?',
          options: ['US Citizen', 'H1B Visa', 'Green Card holder', 'EAD', 'Other'].map { |option| { value: option } },
          type_of_question: 'DROPDOWN',
        },

        {
          question: 'How much notice do you need for an interview?',
          options: ['1 day', '2 day', '1 weeks', 'It depends'].map { |option| { value: option } },
          type_of_question: 'DROPDOWN',
        },

        {
          question: 'What is the best time for a phone or onsite interview?',
          options: ['Mornings (8am – 12pm)', 'Afternoon (12pm – 5pm)'].map { |option| { value: option } },
          type_of_question: 'DROPDOWN',
        },

        {
          question: 'How soon can you start if an offer is made?',
          options: ['Immediately', '1 – 2 weeks', '2 – 3 weeks', 'Not Sure'].map { |option| { value: option } },
          type_of_question: 'DROPDOWN',
        },
      ]
    end
  end
end
