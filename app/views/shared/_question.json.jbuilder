json.call(
  question,
  :id,
  :question,
  :questionnaire_id,
  :type_of_question,
  :is_shared,
  :display_order,
  :page_number,
  :user_id,
  :mandatory,
  :score_question,
  :is_date,
  :is_time,
  :is_range,
  :rating_scale,
  :rating_shape,
  :shape_color,
  :is_option_label,
  :options,
  :removed
)

json.tags question.tags, :id, :name
