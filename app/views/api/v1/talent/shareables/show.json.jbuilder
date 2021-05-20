json.call(@shareable, :id, :job_id, :share_link_id, :talent_id)

if @shareable.job.questionnaire
  answers = @shareable.questionnaire_answers
  json.questionnaire @shareable.job.questionnaire.questions do |question|
    json.call(
      question,
      :question,
      :type_of_question,
      :options
    )

    answer = answers.select { |a| a.question_id == question.id }.first
    json.answer answer&.answer
    json.id answer&.id
    json.question_id question.id
  end
end
