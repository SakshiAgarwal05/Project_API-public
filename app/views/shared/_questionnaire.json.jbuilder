json.questionnaire talents_job.recent_signed_rtr.questionnaire_answers.order(display_order: :asc) do |answer|
  json.call(
    answer,
    :id,
    :question,
    :type_of_question,
    :is_shared,
    :display_order,
    :page_number,
    :mandatory,
    :score_question,
    :is_date,
    :is_time,
    :is_range,
    :rating_scale,
    :rating_shape,
    :shape_color,
    :is_option_label,
    :talent_answer,
    :talent_rating,
    :is_liked,
    :rtr_id
  )

  if answer.type_of_question.eql?('FILE_UPLOAD')
    json.options do
      json.array! answer.options do |option|
        json.value option['value']
        json.file_path SignedUrl.get(option['file_path']) if option['file_path'].present?
      end
    end
  else
    json.options answer.options
  end
end
